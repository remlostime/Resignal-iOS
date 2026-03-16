//
//  ChatService.swift
//  Resignal
//
//  Service for interactive Q&A chat about analyzed sessions.
//

import Foundation

/// Errors that can occur during chat operations
enum ChatError: LocalizedError {
    case sessionNotFound
    case noAnalysisAvailable
    case aiRequestFailed
    case emptyMessage
    case invalidInterviewId
    case networkError(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found."
        case .noAnalysisAvailable:
            return "No analysis available for this session. Please analyze the session first."
        case .aiRequestFailed:
            return "Failed to get response from AI. Please try again."
        case .emptyMessage:
            return "Message cannot be empty."
        case .invalidInterviewId:
            return "Invalid interview ID. Please ensure the session is synced with the server."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

/// Protocol defining chat service capabilities
protocol ChatService: Actor {
    /// Load messages for an interview from the backend
    func loadMessages(interviewId: String) async throws -> [ChatMessage]
    
    /// Send a message about an interview and get AI response.
    /// User identity is derived from the JWT token; no userId parameter needed.
    func sendMessage(
        _ message: String,
        interviewId: String
    ) async throws -> (reply: String, messageId: String)
}
