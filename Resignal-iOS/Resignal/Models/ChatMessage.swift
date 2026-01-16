//
//  ChatMessage.swift
//  Resignal
//
//  Model for chat messages in the Ask feature.
//

import Foundation
import SwiftData

/// Role of a chat message sender
enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Represents a single message in a chat conversation
@Model
final class ChatMessage {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role.rawValue
        self.content = content
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Returns the role as an enum
    var chatRole: ChatRole {
        get { ChatRole(rawValue: role) ?? .user }
        set { role = newValue.rawValue }
    }
    
    /// Returns true if the message is from the user
    var isUser: Bool {
        chatRole == .user
    }
    
    /// Returns true if the message is from the assistant
    var isAssistant: Bool {
        chatRole == .assistant
    }
}

// MARK: - Sample Data

extension ChatMessage {
    static var sampleUser: ChatMessage {
        ChatMessage(
            role: .user,
            content: "Can you explain more about the strengths you identified?"
        )
    }
    
    static var sampleAssistant: ChatMessage {
        ChatMessage(
            role: .assistant,
            content: "Based on your interview responses, the main strengths I identified were:\n\n1. Technical depth in system design\n2. Clear communication style\n3. Quantifiable impact metrics"
        )
    }
}
