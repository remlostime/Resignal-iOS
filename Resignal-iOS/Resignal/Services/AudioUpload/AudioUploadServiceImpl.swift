//
//  AudioUploadServiceImpl.swift
//  Resignal
//
//  Chunked audio upload pipeline:
//    1. Split recording into ≤20MB chunks (AudioChunkManager)
//    2. POST /api/transcriptions          → create transcription job
//    3. POST /api/transcriptions/:id/chunks  → upload each chunk (multipart/form-data)
//    4. POST /api/interviews/:id/transcribe-complete → signal backend to finalize
//    5. GET  /api/transcriptions/:id       → poll until transcript is ready
//
//  Each chunk is retried up to 2 times on transient network failure.
//

import Foundation

// MARK: - Implementation

actor AudioUploadServiceImpl: AudioUploadService {

    // MARK: - Configuration

    private enum Config {
        static let maxRetries = 2
        static let initialRetryDelay: UInt64 = 1_000_000_000
        static let pollingInterval: UInt64 = 3_000_000_000
        static let pollingTimeout: TimeInterval = 300
        static let requestTimeout: TimeInterval = 120
    }

    // MARK: - Dependencies

    private let baseURL: String
    private let identityManager: IdentityManagerProtocol
    private let chunkManager: AudioChunkManager

    // MARK: - State

    private var currentState: TranscriptionUploadState = .idle
    private var stateContinuations: [UUID: AsyncStream<TranscriptionUploadState>.Continuation] = [:]
    private var isCancelled = false

    // MARK: - Initialization

    init(
        baseURL: String,
        identityManager: IdentityManagerProtocol,
        chunkManager: AudioChunkManager = AudioChunkManagerImpl()
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.identityManager = identityManager
        self.chunkManager = chunkManager
    }

    // MARK: - AudioUploadService

    func uploadInterviewAudio(fileURL: URL, interviewId: String?) async throws -> String {
        isCancelled = false
        var chunks: [AudioChunkMetadata] = []

        defer { if !chunks.isEmpty { chunkManager.cleanupChunks(chunks) } }

        let directoryId = interviewId ?? UUID().uuidString

        do {
            setState(.preparing)
            chunks = try chunkManager.splitAudioFile(at: fileURL, interviewId: directoryId)
            try checkCancellation()

            let jobId = try await createTranscriptionJob(totalChunks: chunks.count)
            try checkCancellation()

            for (index, chunk) in chunks.enumerated() {
                try checkCancellation()
                try await uploadChunkWithRetry(chunk: chunk, jobId: jobId)
                setState(.uploading(progress: Double(index + 1) / Double(chunks.count)))
            }

            try checkCancellation()
            if let interviewId {
                try await signalTranscriptionComplete(interviewId: interviewId)
            }

            setState(.processing)
            let transcript = try await pollForTranscript(jobId: jobId)
            setState(.completed(transcript: transcript))
            return transcript

        } catch let error as AudioUploadError where error.isCancellation {
            setState(.failed(errorMessage: error.localizedDescription))
            throw error
        } catch {
            let mapped = (error as? AudioUploadError)
                ?? .uploadFailed(chunkIndex: -1, underlying: error)
            setState(.failed(errorMessage: mapped.localizedDescription))
            throw mapped
        }
    }

    func observeState() -> AsyncStream<TranscriptionUploadState> {
        let streamId = UUID()
        return AsyncStream { continuation in
            continuation.yield(self.currentState)
            self.stateContinuations[streamId] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeObserver(id: streamId) }
            }
        }
    }

    func cancel() {
        isCancelled = true
        setState(.failed(errorMessage: AudioUploadError.cancelled.localizedDescription))
    }

    // MARK: - State Helpers

    private func setState(_ state: TranscriptionUploadState) {
        currentState = state
        for (_, continuation) in stateContinuations { continuation.yield(state) }
    }

    private func removeObserver(id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }

    private func checkCancellation() throws {
        if isCancelled { throw AudioUploadError.cancelled }
        try Task.checkCancellation()
    }
}

// MARK: - API Calls

extension AudioUploadServiceImpl {

    /// POST /api/transcriptions  →  { success, jobId, status }
    private func createTranscriptionJob(totalChunks: Int) async throws -> String {
        let url = try buildURL(path: "/api/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["totalChunks": totalChunks])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jobId = json["jobId"] as? String else {
            throw AudioUploadError.jobCreationFailed("Missing jobId in response.")
        }
        return jobId
    }

    /// Uploads a single chunk with up to `Config.maxRetries` retries on transient failure.
    private func uploadChunkWithRetry(chunk: AudioChunkMetadata, jobId: String) async throws {
        var lastError: Error?

        for attempt in 0...Config.maxRetries {
            do {
                try checkCancellation()
                try await uploadSingleChunk(chunk: chunk, jobId: jobId)
                return
            } catch {
                lastError = error
                if isNonRetryable(error) { throw error }
                if attempt < Config.maxRetries {
                    let delay = Config.initialRetryDelay * UInt64(1 << attempt)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw AudioUploadError.uploadFailed(
            chunkIndex: chunk.chunkIndex,
            underlying: lastError ?? AudioUploadError.invalidResponse
        )
    }

    /// POST /api/transcriptions/:jobId/chunks  (multipart/form-data)
    private func uploadSingleChunk(chunk: AudioChunkMetadata, jobId: String) async throws {
        let url = try buildURL(path: "/api/transcriptions/\(jobId)/chunks")
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Config.requestTimeout
        applyAuthHeaders(to: &request)

        let bodyFileURL = try MultipartBodyBuilder.buildMultipartFile(
            boundary: boundary,
            chunkIndex: chunk.chunkIndex,
            audioFileURL: chunk.fileURL
        )
        defer { try? FileManager.default.removeItem(at: bodyFileURL) }

        let bodyData = try Data(contentsOf: bodyFileURL)
        let (data, response) = try await URLSession.shared.upload(for: request, from: bodyData)
        try validateHTTPResponse(response, data: data)
    }

    /// POST /api/interviews/:interviewId/transcribe-complete
    private func signalTranscriptionComplete(interviewId: String) async throws {
        let url = try buildURL(path: "/api/interviews/\(interviewId)/transcribe-complete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
    }

    /// GET /api/transcriptions/:jobId  →  { status, resultUrl?, ... }
    ///
    /// Polls until the job completes, then downloads the full transcript from the
    /// Blob CDN URL returned in `resultUrl`.
    private func pollForTranscript(jobId: String) async throws -> String {
        let decoder = JSONDecoder()
        let startTime = Date()

        while true {
            try checkCancellation()
            if Date().timeIntervalSince(startTime) > Config.pollingTimeout {
                throw AudioUploadError.pollingTimeout
            }

            let url = try buildURL(path: "/api/transcriptions/\(jobId)")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyAuthHeaders(to: &request)

            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)

            let status = try decoder.decode(TranscriptionStatusResponse.self, from: data)

            switch status.status {
            case "completed":
                return try await downloadTranscriptionResult(
                    from: status.resultUrl,
                    decoder: decoder
                )
            case "failed":
                throw AudioUploadError.serverError(
                    statusCode: 0,
                    message: "Transcription failed on server."
                )
            default:
                break
            }

            try await Task.sleep(nanoseconds: Config.pollingInterval)
        }
    }

    /// Downloads and decodes the transcript payload from a public Blob CDN URL.
    private func downloadTranscriptionResult(
        from urlString: String?,
        decoder: JSONDecoder
    ) async throws -> String {
        guard let urlString, let blobURL = URL(string: urlString) else {
            throw AudioUploadError.resultDownloadFailed("Missing or invalid resultUrl.")
        }

        let (data, response) = try await URLSession.shared.data(from: blobURL)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AudioUploadError.resultDownloadFailed(
                "HTTP \(http.statusCode) from result URL."
            )
        }

        do {
            let result = try decoder.decode(TranscriptionResult.self, from: data)
            return result.transcript
        } catch {
            throw AudioUploadError.resultDownloadFailed(
                "Failed to parse result JSON: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Networking Helpers

extension AudioUploadServiceImpl {

    private func applyAuthHeaders(to request: inout URLRequest) {
        if let token = identityManager.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(identityManager.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(identityManager.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(identityManager.deviceModel, forHTTPHeaderField: "x-device-model")
    }

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AudioUploadError.invalidResponse
        }
        return url
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AudioUploadError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw AudioUploadError.unauthorized
        case 413:
            throw AudioUploadError.fileTooLarge
        default:
            let message: String
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorObj = json["error"] as? [String: Any], let msg = errorObj["message"] as? String {
                    message = msg
                } else if let msg = json["message"] as? String {
                    message = msg
                } else if let error = json["error"] as? String {
                    message = error
                } else {
                    message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                }
            } else {
                message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            }
            throw AudioUploadError.serverError(statusCode: http.statusCode, message: message)
        }
    }

    private func isNonRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        guard let uploadError = error as? AudioUploadError else { return false }
        switch uploadError {
        case .cancelled, .unauthorized, .fileTooLarge:
            return true
        default:
            return false
        }
    }
}

// MARK: - Mock Implementation

actor MockAudioUploadService: AudioUploadService {

    var mockTranscript = "This is a mock transcript from the server."
    var shouldFail = false
    var simulatedDelay: UInt64 = 500_000_000

    private var currentState: TranscriptionUploadState = .idle
    private var continuations: [UUID: AsyncStream<TranscriptionUploadState>.Continuation] = [:]

    func uploadInterviewAudio(fileURL: URL, interviewId: String?) async throws -> String {
        guard !shouldFail else {
            broadcastState(.failed(errorMessage: "Mock upload failure"))
            throw AudioUploadError.uploadFailed(chunkIndex: 0, underlying: AudioUploadError.invalidResponse)
        }

        broadcastState(.preparing)
        try await Task.sleep(nanoseconds: simulatedDelay)

        for step in 1...3 {
            broadcastState(.uploading(progress: Double(step) / 3.0))
            try await Task.sleep(nanoseconds: simulatedDelay)
        }

        broadcastState(.processing)
        try await Task.sleep(nanoseconds: simulatedDelay)

        broadcastState(.completed(transcript: mockTranscript))
        return mockTranscript
    }

    func observeState() -> AsyncStream<TranscriptionUploadState> {
        let streamId = UUID()
        return AsyncStream { continuation in
            continuation.yield(self.currentState)
            self.continuations[streamId] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeContinuation(id: streamId) }
            }
        }
    }

    func cancel() {
        broadcastState(.failed(errorMessage: "Cancelled"))
    }

    private func broadcastState(_ state: TranscriptionUploadState) {
        currentState = state
        for (_, cont) in continuations { cont.yield(state) }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
