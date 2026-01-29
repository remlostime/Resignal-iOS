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
    
    private let aiClient: any AIClient
    private let sessionRepository: SessionRepositoryProtocol
    private let chatService: ChatService
    
    let session: Session
    var regenerateState: VoidState = .idle
    
    // Tab state
    var selectedTab: ResultTab = .feedback
    
    // Chat state
    var chatMessages: [ChatMessage] = []
    var askMessage: String = ""
    var isSendingMessage: Bool = false
    var chatError: String?
    
    // MARK: - Computed Properties
    
    var isRegenerating: Bool {
        regenerateState.isLoading
    }
    
    var errorMessage: String? {
        regenerateState.error
    }
    
    var showError: Bool {
        get { regenerateState.hasError }
        set { if !newValue { clearError() } }
    }
    
    // MARK: - Initialization
    
    init(
        session: Session,
        aiClient: any AIClient,
        sessionRepository: SessionRepositoryProtocol,
        chatService: ChatService
    ) {
        self.session = session
        self.aiClient = aiClient
        self.sessionRepository = sessionRepository
        self.chatService = chatService
        self.chatMessages = session.chatHistory
    }
    
    // MARK: - Public Methods
    
    /// Regenerates the analysis
    func regenerate() async {
        regenerateState = .loading
        
        do {
            let request = AnalysisRequest(inputText: session.inputText)
            
            let response = try await aiClient.analyze(request)
            
            // Update session
            session.outputFeedback = response.feedback
            session.version += 1
            try sessionRepository.update(session, title: nil, tags: nil)
            
            regenerateState = .success(.empty)
            
        } catch let error as AIClientError {
            regenerateState = .error(error.localizedDescription)
            debugLog("Regenerate error: \(error)")
        } catch {
            regenerateState = .error("An unexpected error occurred.")
            debugLog("Unexpected error: \(error)")
        }
    }
    
    /// Clears any error state
    func clearError() {
        if regenerateState.hasError {
            regenerateState = .idle
        }
        chatError = nil
    }
    
    /// Sends a chat message
    func sendAskMessage() async {
        let trimmedMessage = askMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
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
            let response = try await chatService.sendMessage(
                trimmedMessage,
                session: session,
                conversationHistory: chatMessages
            )
            
            // Add assistant message
            let assistantMessage = ChatMessage(role: .assistant, content: response)
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
