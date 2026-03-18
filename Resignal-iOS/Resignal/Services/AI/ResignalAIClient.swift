//
//  ResignalAIClient.swift
//  Resignal
//
//  AI client that integrates with Resignal backend API for interview analysis.
//

import Foundation

/// Resignal backend API client for interview analysis.
/// Uses the centralized APIClient for authenticated requests.
actor ResignalAIClient: AIClient {

    // MARK: - Request/Response Models

    struct ChatRequest: Encodable, Sendable {
        let input: String
        let task: String
        let locale: String
        let image: ImageAttachment?
        let model: String?
        
        init(input: String, task: String = "feedback", locale: String = "en", image: ImageAttachment? = nil, model: String? = nil) {
            self.input = input
            self.task = task
            self.locale = locale
            self.image = image
            self.model = model
        }
    }

    struct ChatResponse: Decodable, Sendable {
        let provider: String
        let interviewId: String
        let reply: StructuredFeedback
    }

    struct ErrorResponse: Decodable, Sendable {
        let error: String
    }

    // MARK: - Properties

    private let model: String
    private let apiClient: APIClientProtocol
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
        model: String = "gemini",
        apiClient: APIClientProtocol
    ) {
        self.model = model
        self.apiClient = apiClient
    }

    // MARK: - AIClient Implementation

    nonisolated func analyze(_ request: AnalysisRequest) async throws -> AnalysisResponse {
        let trimmedInput = request.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.count >= ValidationConstants.minimumInputCharacters else {
            throw AIClientError.invalidInput("Input text must be at least \(ValidationConstants.minimumInputCharacters) characters")
        }

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
        
        let completeInput = request.inputText
        let chatRequest = ChatRequest(input: completeInput, image: request.image, model: model)

        let (data, _) = try await apiClient.requestRaw(
            "/api/interviews",
            method: .post,
            body: chatRequest,
            timeoutInterval: 60
        )

        try Task.checkCancellation()

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let chatResponse = try decoder.decode(ChatResponse.self, from: data)
            return AnalysisResponse(feedback: chatResponse.reply, interviewId: chatResponse.interviewId)
        } catch {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw AIClientError.apiError(errorResponse.error)
            }
            throw AIClientError.apiError("Failed to decode response")
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
