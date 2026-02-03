//
//  ResignalAIClient.swift
//  Resignal
//
//  AI client that integrates with Resignal backend API for interview analysis.
//

import Foundation

/// Resignal backend API client
/// Integrates with the Resignal backend at https://resignal-backend.vercel.app
actor ResignalAIClient: AIClient {

    // MARK: - Request/Response Models

    struct ChatRequest: Encodable, Sendable {
        let input: String
    }

    struct ChatResponse: Decodable, Sendable {
        let provider: String
        let interviewId: String
        let reply: StructuredFeedback
        
        enum CodingKeys: String, CodingKey {
            case provider
            case interviewId = "interview_id"
            case reply
        }
    }

    struct ErrorResponse: Decodable, Sendable {
        let error: String
    }

    // MARK: - Properties

    private let baseURL: String
    private let clientContextService: ClientContextServiceProtocol
    private var _isAnalyzing: Bool = false
    private var currentTask: Task<AnalysisResponse, Error>?

    nonisolated var isAnalyzing: Bool {
        get async {
            await getIsAnalyzing()
        }
    }

    private func getIsAnalyzing() -> Bool {
        _isAnalyzing
    }

    // MARK: - Initialization

    init(
        baseURL: String = "https://resignal-backend.vercel.app",
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.clientContextService = clientContextService
    }

    // MARK: - AIClient Implementation

    nonisolated func analyze(_ request: AnalysisRequest) async throws -> AnalysisResponse {
        // Validate input
        let trimmedInput = request.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.count >= ValidationConstants.minimumInputCharacters else {
            throw AIClientError.invalidInput("Input text must be at least \(ValidationConstants.minimumInputCharacters) characters")
        }

        // Create and store the task for cancellation support
        let task = Task<AnalysisResponse, Error> {
            try await performAnalysis(request: request)
        }
        
        await setCurrentTask(task)
        
        do {
            let result = try await task.value
            await clearCurrentTask()
            return result
        } catch {
            await clearCurrentTask()
            if Task.isCancelled {
                throw AIClientError.cancelled
            }
            throw error
        }
    }

    nonisolated func cancel() {
        Task {
            await cancelCurrentTask()
        }
    }

    // MARK: - Private Methods
    
    private func performAnalysis(request: AnalysisRequest) async throws -> AnalysisResponse {
        await setIsAnalyzing(true)
        defer { Task { await setIsAnalyzing(false) } }
        
        // Send only the raw transcript
        let completeInput = request.inputText

        // Create the request
        let chatRequest = ChatRequest(input: completeInput)

        // Create URL request
        guard let url = URL(string: "\(baseURL)/api/interviews") else {
            throw AIClientError.networkError("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(clientContextService.clientId, forHTTPHeaderField: "x-client-id")
        urlRequest.setValue(clientContextService.appVersion, forHTTPHeaderField: "x-client-version")
        urlRequest.setValue(clientContextService.platform, forHTTPHeaderField: "x-client-platform")
        urlRequest.setValue(clientContextService.deviceModel, forHTTPHeaderField: "x-device-model")
        urlRequest.timeoutInterval = 60

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(chatRequest)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatResponse.self, from: data)

            return AnalysisResponse(feedback: chatResponse.reply, interviewId: chatResponse.interviewId)

        case 500:
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AIClientError.apiError(errorResponse.error)
            }
            throw AIClientError.apiError("Server error (HTTP 500)")

        default:
            // Try to parse error response for other status codes
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AIClientError.apiError(errorResponse.error)
            }
            throw AIClientError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    private func setCurrentTask(_ task: Task<AnalysisResponse, Error>) {
        currentTask = task
    }
    
    private func clearCurrentTask() {
        currentTask = nil
    }
    
    private func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        _isAnalyzing = false
    }
    
    private func setIsAnalyzing(_ value: Bool) {
        _isAnalyzing = value
    }
}
