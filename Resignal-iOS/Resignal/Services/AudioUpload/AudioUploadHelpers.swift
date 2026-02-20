//
//  AudioUploadHelpers.swift
//  Resignal
//
//  Background URLSession delegate, thread-safe continuation store, and multipart
//  form-data builder used by AudioUploadServiceImpl.
//

import Foundation

// MARK: - Background Upload Delegate

/// Bridges URLSession delegate callbacks to per-task continuations so the actor can
/// await the result of each background upload.
final class BackgroundUploadDelegate: NSObject, URLSessionDataDelegate, Sendable {

    private let store = TaskContinuationStore()

    func registerContinuation(
        for taskIdentifier: Int,
        completion: @escaping @Sendable (Result<(Data, URLResponse), Error>) -> Void
    ) {
        store.store(taskIdentifier: taskIdentifier, completion: completion)
    }

    // MARK: - Collect response body data

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        store.appendData(data, for: dataTask.taskIdentifier)
    }

    // MARK: - Task completion

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            store.complete(taskIdentifier: task.taskIdentifier, result: .failure(error))
        } else {
            let data = store.collectedData(for: task.taskIdentifier)
            let response = task.response ?? HTTPURLResponse()
            store.complete(taskIdentifier: task.taskIdentifier, result: .success((data, response)))
        }
    }

    // MARK: - Background session events

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // The app delegate should call the stored completion handler here.
        // Hook point for UIApplicationDelegate.handleEventsForBackgroundURLSession.
    }
}

// MARK: - Thread-Safe Continuation Store

/// Lock-protected storage mapping task identifiers to their continuations and accumulated data.
final class TaskContinuationStore: @unchecked Sendable {

    private let lock = NSLock()
    private var completions: [Int: @Sendable (Result<(Data, URLResponse), Error>) -> Void] = [:]
    private var dataBuffers: [Int: Data] = [:]

    func store(
        taskIdentifier: Int,
        completion: @escaping @Sendable (Result<(Data, URLResponse), Error>) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        completions[taskIdentifier] = completion
        dataBuffers[taskIdentifier] = Data()
    }

    func appendData(_ data: Data, for taskIdentifier: Int) {
        lock.lock()
        defer { lock.unlock() }
        dataBuffers[taskIdentifier, default: Data()].append(data)
    }

    func collectedData(for taskIdentifier: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }
        return dataBuffers[taskIdentifier] ?? Data()
    }

    func complete(taskIdentifier: Int, result: Result<(Data, URLResponse), Error>) {
        lock.lock()
        let completion = completions.removeValue(forKey: taskIdentifier)
        dataBuffers.removeValue(forKey: taskIdentifier)
        lock.unlock()
        completion?(result)
    }
}

// MARK: - Multipart Form-Data Builder

/// Builds a multipart/form-data body for uploading a single audio chunk and writes
/// it to a temporary file suitable for `uploadTask(with:fromFile:)`.
enum MultipartBodyBuilder {

    /// Constructs the multipart body containing a `chunkIndex` text field and the audio
    /// file, then writes it to a temp file and returns its URL.
    static func buildMultipartFile(
        boundary: String,
        chunkIndex: Int,
        audioFileURL: URL
    ) throws -> URL {
        let crlf = "\r\n"
        var body = Data()

        // -- chunkIndex text field --
        body.appendUTF8("--\(boundary)\(crlf)")
        body.appendUTF8("Content-Disposition: form-data; name=\"chunkIndex\"\(crlf)\(crlf)")
        body.appendUTF8("\(chunkIndex)\(crlf)")

        // -- audio file field --
        let filename = audioFileURL.lastPathComponent
        let mimeType = mimeTypeForExtension(audioFileURL.pathExtension)

        body.appendUTF8("--\(boundary)\(crlf)")
        body.appendUTF8("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)")
        body.appendUTF8("Content-Type: \(mimeType)\(crlf)\(crlf)")

        let audioData = try Data(contentsOf: audioFileURL)
        body.append(audioData)
        body.appendUTF8(crlf)

        // -- closing boundary --
        body.appendUTF8("--\(boundary)--\(crlf)")

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("upload_\(UUID().uuidString).tmp")
        try body.write(to: tempFile, options: .atomic)
        return tempFile
    }

    static func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "m4a":  return "audio/m4a"
        case "mp4":  return "audio/mp4"
        case "mp3":  return "audio/mpeg"
        case "wav":  return "audio/wav"
        case "webm": return "audio/webm"
        default:     return "audio/m4a"
        }
    }
}

// MARK: - Data + UTF-8 Append

extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - AudioUploadError Helpers

extension AudioUploadError {
    var isCancellation: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
