//
//  ChatServiceImpl.swift
//  Resignal
//
//  Implementation of chat service using the centralized APIClient.
//

import Foundation

/// Implementation of ChatService
actor ChatServiceImpl: ChatService {
    
    // MARK: - API Response Models
    
    private struct MessagesResponse: Decodable {
        let success: Bool
        let messages: [MessageDTO]
    }
    
    private struct MessageDTO: Decodable {
        let id: String
        let interviewId: String
        let role: String
        let content: String
        let createdAt: String
    }
    
    /// Request model for POST /api/messages (userId removed; identity from JWT)
    private struct SendMessageRequest: Encodable {
        let interviewId: String
        let message: String
        let model: String?
        
        enum CodingKeys: String, CodingKey {
            case interviewId = "interview_id"
            case message
            case model
        }
    }
    
    private struct SendMessageResponse: Decodable {
        let success: Bool
        let reply: String
        let messageId: String
    }
    
    // MARK: - Properties
    
    private let model: String
    private let apiClient: APIClientProtocol
    
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // MARK: - Initialization
    
    init(
        model: String = "gemini",
        apiClient: APIClientProtocol
    ) {
        self.model = model
        self.apiClient = apiClient
    }
    
    // MARK: - ChatService Implementation
    
    func loadMessages(interviewId: String) async throws -> [ChatMessage] {
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        do {
            let response: MessagesResponse = try await apiClient.request(
                "/api/interviews/\(interviewId)/messages"
            )
            return response.messages.map { mapDTOToChatMessage($0) }
        } catch let error as APIError {
            throw mapToChatError(error)
        }
    }
    
    func sendMessage(
        _ message: String,
        interviewId: String
    ) async throws -> (reply: String, messageId: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard !interviewId.isEmpty else {
            throw ChatError.invalidInterviewId
        }
        
        let requestBody = SendMessageRequest(
            interviewId: interviewId,
            message: trimmedMessage,
            model: model
        )
        
        do {
            let response: SendMessageResponse = try await apiClient.request(
                "/api/messages",
                method: .post,
                body: requestBody,
                timeoutInterval: 60
            )
            return (reply: response.reply, messageId: response.messageId)
        } catch let error as APIError {
            throw mapToChatError(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func mapToChatError(_ error: APIError) -> ChatError {
        switch error {
        case .notFound:
            return .sessionNotFound
        case .networkError(let msg):
            return .networkError(msg)
        case .internalError(let msg):
            return .serverError(msg)
        default:
            return .aiRequestFailed
        }
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
        
        try await Task.sleep(nanoseconds: 200_000_000)
        return mockMessages
    }
    
    func sendMessage(
        _ message: String,
        interviewId: String
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
        
        try await Task.sleep(nanoseconds: 500_000_000)
        return (reply: mockReply, messageId: mockMessageId)
    }
}
