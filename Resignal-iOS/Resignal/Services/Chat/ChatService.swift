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
        }
    }
}

/// Protocol defining chat service capabilities
protocol ChatService: Actor {
    /// Send a message about a session and get AI response
    /// - Parameters:
    ///   - message: The user's question or message
    ///   - session: The session to ask about
    ///   - conversationHistory: Previous messages in the conversation
    /// - Returns: AI's response message
    func sendMessage(
        _ message: String,
        session: Session,
        conversationHistory: [ChatMessage]
    ) async throws -> String
    
    /// Generate a summary of the conversation
    /// - Parameter messages: The conversation messages
    /// - Returns: A summary of the conversation
    func summarizeConversation(_ messages: [ChatMessage]) async throws -> String
}
