//
//  InterviewDetailViewModel.swift
//  Resignal
//
//  ViewModel for the server-driven interview detail screen.
//

import Foundation
import SwiftUI

/// Tab selection for interview detail view
enum InterviewDetailTab: String, CaseIterable {
    case feedback = "Feedback"
    case transcript = "Transcript"
    case ask = "Ask"
}

/// ViewModel managing the interview detail screen state
@MainActor
@Observable
final class InterviewDetailViewModel: InterviewDetailViewModelProtocol {
    
    // MARK: - Properties
    
    private let interviewClient: any InterviewClient
    private let chatService: ChatService
    private let clientContextService: ClientContextServiceProtocol
    private let featureAccessService: FeatureAccessServiceProtocol
    
    let interviewId: String
    
    // Detail state
    var state: ViewState<StructuredFeedback> = .idle
    
    // Tab state
    var selectedTab: InterviewDetailTab = .feedback
    
    // Chat state
    var chatMessages: [ChatMessage] = []
    var askMessage: String = ""
    var isSendingMessage: Bool = false
    var isLoadingMessages: Bool = false
    var hasLoadedMessages: Bool = false
    var chatError: String?
    
    // Paywall state
    var showPaywall: Bool = false
    
    // MARK: - Computed Properties
    
    var feedback: StructuredFeedback? {
        state.value
    }
    
    var errorMessage: String? {
        chatError ?? state.error
    }
    
    var showError: Bool {
        get { chatError != nil }
        set { if !newValue { clearError() } }
    }
    
    var canSendAskMessage: Bool {
        featureAccessService.canSendAskMessage(forSessionId: interviewId)
    }
    
    // MARK: - Initialization
    
    init(
        interviewId: String,
        interviewClient: any InterviewClient,
        chatService: ChatService,
        featureAccessService: FeatureAccessServiceProtocol,
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared
    ) {
        self.interviewId = interviewId
        self.interviewClient = interviewClient
        self.chatService = chatService
        self.featureAccessService = featureAccessService
        self.clientContextService = clientContextService
    }
    
    // MARK: - Public Methods
    
    /// Fetches the interview detail from the backend
    func loadDetail() async {
        guard !state.isLoading else { return }
        state = .loading
        
        do {
            let detail = try await interviewClient.fetchInterviewDetail(id: interviewId)
            state = .success(detail)
        } catch {
            state = .error(error.localizedDescription)
            debugLog("Failed to load interview detail: \(error)")
        }
    }
    
    /// Clears any error state
    func clearError() {
        chatError = nil
    }
    
    /// Loads chat messages from the backend
    func loadMessages() async {
        guard !isLoadingMessages, !hasLoadedMessages else { return }
        
        isLoadingMessages = true
        
        do {
            let serverMessages = try await chatService.loadMessages(interviewId: interviewId)
            chatMessages = serverMessages
            hasLoadedMessages = true
            isLoadingMessages = false
            debugLog("Loaded \(serverMessages.count) messages from server")
        } catch {
            hasLoadedMessages = true
            isLoadingMessages = false
            debugLog("Failed to load messages from server: \(error)")
        }
    }
    
    /// Sends a chat message
    func sendAskMessage() async {
        let trimmedMessage = askMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        guard canSendAskMessage else {
            showPaywall = true
            return
        }
        
        let userMessage = ChatMessage(role: .user, content: trimmedMessage)
        chatMessages.append(userMessage)
        
        askMessage = ""
        isSendingMessage = true
        
        do {
            let userId = clientContextService.clientId
            let (reply, messageId) = try await chatService.sendMessage(
                trimmedMessage,
                interviewId: interviewId,
                userId: userId
            )
            
            let assistantMessage = ChatMessage(
                role: .ai,
                content: reply,
                serverId: messageId
            )
            chatMessages.append(assistantMessage)
            
            featureAccessService.recordAskMessage(forSessionId: interviewId)
            isSendingMessage = false
        } catch {
            chatError = error.localizedDescription
            isSendingMessage = false
            debugLog("Chat error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[InterviewDetailViewModel] \(message)")
        #endif
    }
}
