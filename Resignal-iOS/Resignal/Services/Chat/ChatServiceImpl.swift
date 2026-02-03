//
//  ChatServiceImpl.swift
//  Resignal
//
//  Implementation of chat service using direct API calls to the Resignal backend.
//

import Foundation

/// Implementation of ChatService
actor ChatServiceImpl: ChatService {
    
    // MARK: - API Response Models
    
    /// Response model for GET /api/interviews/:interviewId/messages
    private struct MessagesResponse: Decodable {
        let success: Bool
        let messages: [MessageDTO]
    }
    
    /// Individual message from the API
    private struct MessageDTO: Decodable {
        let id: String
        let interviewId: String
        let role: String
        let content: String
        let createdAt: String
    }
    
    /// Request model for POST /api/messages
    private struct SendMessageRequest: Encodable {
        let interviewId: String
        let message: String
        let userId: String
        
        enum CodingKeys: String, CodingKey {
            case interviewId = "interview_id"
            case message
            case userId = "user_id"
        }
    }
    
    /// Response model for POST /api/messages
    private struct SendMessageResponse: Decodable {
        let success: Bool
        let reply: String
        let messageId: String
    }
    
    /// Error response from the API
    private struct ErrorResponse: Decodable {
        let error: String
    }
    
    // MARK: - Properties
    
    private let baseURL: String
    private let clientContextService: ClientContextServiceProtocol
    private let urlSession: URLSession
    
    // ISO8601 date formatter for parsing API dates
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Fallback formatter without fractional seconds
    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // MARK: - Initialization
    
    init(
        baseURL: String = "https://resignal-backend.vercel.app",
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.clientContextService = clientContextService
        self.urlSession = urlSession
    }
    
    // MARK: - ChatService Implementation
    
    func loadMessages(interviewId: String) async throws -> [ChatMessage] {
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/api/interviews/\(interviewId)/messages") else {
            throw ChatError.networkError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addClientHeaders(to: &urlRequest)
        urlRequest.timeoutInterval = 30
        
        // Execute request
        let (data, response) = try await executeRequest(urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let messagesResponse = try decoder.decode(MessagesResponse.self, from: data)
            return messagesResponse.messages.map { dto in
                mapDTOToChatMessage(dto)
            }
            
        case 404:
            throw ChatError.sessionNotFound
            
        default:
            throw parseErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
    }
    
    func sendMessage(
        _ message: String,
        interviewId: String,
        userId: String
    ) async throws -> (reply: String, messageId: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/api/messages") else {
            throw ChatError.networkError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addClientHeaders(to: &urlRequest)
        urlRequest.timeoutInterval = 60
        
        // Encode request body
        let requestBody = SendMessageRequest(
            interviewId: interviewId,
            message: trimmedMessage,
            userId: userId
        )
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)
        
        // Execute request
        let (data, response) = try await executeRequest(urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let sendResponse = try decoder.decode(SendMessageResponse.self, from: data)
            return (reply: sendResponse.reply, messageId: sendResponse.messageId)
            
        case 404:
            throw ChatError.sessionNotFound
            
        default:
            throw parseErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Private Helpers
    
    private func addClientHeaders(to request: inout URLRequest) {
        request.setValue(clientContextService.clientId, forHTTPHeaderField: "x-client-id")
        request.setValue(clientContextService.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(clientContextService.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(clientContextService.deviceModel, forHTTPHeaderField: "x-device-model")
    }
    
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw ChatError.networkError(error.localizedDescription)
        }
    }
    
    private func parseErrorResponse(data: Data, statusCode: Int) -> ChatError {
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            if statusCode >= 500 {
                return .serverError(errorResponse.error)
            }
            return .aiRequestFailed
        }
        
        if statusCode >= 500 {
            return .serverError("HTTP \(statusCode)")
        }
        return .networkError("HTTP \(statusCode)")
    }
    
    private func mapDTOToChatMessage(_ dto: MessageDTO) -> ChatMessage {
        let role = ChatRole(rawValue: dto.role) ?? .user
        let timestamp = Self.dateFormatter.date(from: dto.createdAt)
            ?? Self.fallbackDateFormatter.date(from: dto.createdAt)
            ?? Date()
        
        return ChatMessage(
            role: role,
            content: dto.content,
            timestamp: timestamp,
            serverId: dto.id
        )
    }
}

// MARK: - Mock Implementation

actor MockChatService: ChatService {
    var shouldFail = false
    var mockMessages: [ChatMessage] = []
    var mockReply = "This is a mock response to your question about the interview analysis."
    var mockMessageId = UUID().uuidString
    
    func loadMessages(interviewId: String) async throws -> [ChatMessage] {
        guard !shouldFail else {
            throw ChatError.aiRequestFailed
        }
        
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return mockMessages
    }
    
    func sendMessage(
        _ message: String,
        interviewId: String,
        userId: String
    ) async throws -> (reply: String, messageId: String) {
        guard !shouldFail else {
            throw ChatError.aiRequestFailed
        }
        
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return (reply: mockReply, messageId: mockMessageId)
    }
}
