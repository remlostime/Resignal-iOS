//
//  ResultViewModel.swift
//  Resignal
//
//  ViewModel for the analysis result screen.
//

import Foundation
import SwiftUI

/// Tab selection for result view
enum ResultTab: String, CaseIterable {
    case feedback = "Feedback"
    case transcript = "Transcript"
    case ask = "Ask"
}

/// ViewModel managing the result screen state
@MainActor
@Observable
final class ResultViewModel: ResultViewModelProtocol {
    
    // MARK: - Properties
    
    private let sessionRepository: SessionRepositoryProtocol
    private let chatService: ChatService
    private let clientContextService: ClientContextServiceProtocol
    
    let session: Session
    
    // Tab state
    var selectedTab: ResultTab = .feedback
    
    // Chat state
    var chatMessages: [ChatMessage] = []
    var askMessage: String = ""
    var isSendingMessage: Bool = false
    var chatError: String?
    
    // MARK: - Computed Properties
    
    var errorMessage: String? {
        chatError
    }
    
    var showError: Bool {
        get { chatError != nil }
        set { if !newValue { clearError() } }
    }
    
    // MARK: - Initialization
    
    init(
        session: Session,
        sessionRepository: SessionRepositoryProtocol,
        chatService: ChatService,
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared
    ) {
        self.session = session
        self.sessionRepository = sessionRepository
        self.chatService = chatService
        self.clientContextService = clientContextService
        self.chatMessages = session.chatHistory
    }
    
    // MARK: - Public Methods
    
    /// Clears any error state
    func clearError() {
        chatError = nil
    }
    
    /// Sends a chat message
    func sendAskMessage() async {
        let trimmedMessage = askMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // Ensure session has an interview ID
        guard let interviewId = session.interviewId else {
            chatError = "Session not synced with server. Please analyze the interview first."
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmedMessage)
        chatMessages.append(userMessage)
        
        // Save user message
        do {
            try sessionRepository.saveChatMessage(userMessage, to: session)
        } catch {
            debugLog("Failed to save user message: \(error)")
        }
        
        // Clear input
        askMessage = ""
        isSendingMessage = true
        
        do {
            let userId = clientContextService.clientId
            let (reply, messageId) = try await chatService.sendMessage(
                trimmedMessage,
                interviewId: interviewId,
                userId: userId
            )
            
            // Add assistant message with server ID
            let assistantMessage = ChatMessage(
                role: .ai,
                content: reply,
                serverId: messageId
            )
            chatMessages.append(assistantMessage)
            
            // Save assistant message
            try sessionRepository.saveChatMessage(assistantMessage, to: session)
            
            isSendingMessage = false
            
        } catch {
            chatError = error.localizedDescription
            isSendingMessage = false
            debugLog("Chat error: \(error)")
        }
    }
    
    /// Clears chat history
    func clearChatHistory() {
        do {
            try sessionRepository.deleteChatHistory(from: session)
            chatMessages.removeAll()
        } catch {
            chatError = "Failed to clear chat history"
            debugLog("Clear chat error: \(error)")
        }
    }
    
    // MARK: - Private Methods

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ResultViewModel] \(message)")
        #endif
    }
}
