//
//  OpenAICompatibleClient.swift
//  Resignal
//
//  OpenAI-compatible API client for real AI analysis.
//  Placeholder implementation - requires API key configuration.
//

import Foundation

/// OpenAI-compatible API client
/// Supports any API endpoint that implements the OpenAI chat completions API
actor OpenAICompatibleClient: AIClient {

    // MARK: - Request/Response Models

    struct ChatRequest: Encodable, Sendable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
        }

        struct Message: Encodable, Sendable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Decodable, Sendable {
        let choices: [Choice]

        struct Choice: Decodable, Sendable {
            let message: Message
        }

        struct Message: Decodable, Sendable {
            let content: String
        }
    }

    struct ErrorResponse: Decodable, Sendable {
        let error: APIError

        struct APIError: Decodable, Sendable {
            let message: String
            let type: String?
            let code: String?
        }
    }

    // MARK: - Properties

    private let baseURL: String
    private let apiKey: String
    private let model: String
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
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String = "",
        model: String = "gpt-4o-mini"
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        self.model = model
    }

    // MARK: - AIClient Implementation

    nonisolated func analyze(_ request: AnalysisRequest) async throws -> AnalysisResponse {
        // Validate input
        let trimmedInput = request.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.count >= ValidationConstants.minimumInputCharacters else {
            throw AIClientError.invalidInput("Input text must be at least \(ValidationConstants.minimumInputCharacters) characters")
        }

        // Get configuration from actor
        let config = await getConfiguration()

        // Check for API key
        guard !config.apiKey.isEmpty else {
            throw AIClientError.unauthorized
        }

        // Create and store the task for cancellation support
        let task = Task<AnalysisResponse, Error> {
            try await performAnalysis(request: request, config: config)
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
    
    private func performAnalysis(
        request: AnalysisRequest,
        config: (baseURL: String, apiKey: String, model: String)
    ) async throws -> AnalysisResponse {
        await setIsAnalyzing(true)
        defer { Task { await setIsAnalyzing(false) } }
        
        // Build the prompt
        let userPrompt = PromptBuilder.buildPrompt(inputText: request.inputText)

        // Create the request
        let chatRequest = ChatRequest(
            model: config.model,
            messages: [
                ChatRequest.Message(role: "system", content: PromptBuilder.systemPrompt),
                ChatRequest.Message(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            maxTokens: 2000
        )

        // Create URL request
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw AIClientError.networkError("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
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

            guard let content = chatResponse.choices.first?.message.content else {
                throw AIClientError.apiError("Empty response from API")
            }

            return AnalysisResponse(feedback: content)

        case 401:
            throw AIClientError.unauthorized

        case 429:
            throw AIClientError.rateLimited

        default:
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AIClientError.apiError(errorResponse.error.message)
            }
            throw AIClientError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }

    private func getConfiguration() -> (baseURL: String, apiKey: String, model: String) {
        (baseURL, apiKey, model)
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
