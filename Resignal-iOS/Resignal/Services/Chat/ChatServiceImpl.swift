//
//  ChatServiceImpl.swift
//  Resignal
//
//  Implementation of chat service using AIClient.
//

import Foundation

/// Implementation of ChatService
actor ChatServiceImpl: ChatService {
    
    // MARK: - Properties
    
    private let aiClient: AIClient
    
    // MARK: - Initialization
    
    init(aiClient: AIClient) {
        self.aiClient = aiClient
    }
    
    // MARK: - ChatService Implementation
    
    func sendMessage(
        _ message: String,
        session: Session,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard session.hasAnalysis else {
            throw ChatError.noAnalysisAvailable
        }
        
        // Build context-aware prompt
        let prompt = buildChatPrompt(
            userMessage: trimmedMessage,
            session: session,
            history: conversationHistory
        )
        
        // Use AIClient to get response
        let request = AnalysisRequest(
            inputText: prompt,
            role: session.role,
            rubric: session.rubricType
        )
        
        do {
            let response = try await aiClient.analyze(request)
            return response.feedback
        } catch {
            throw ChatError.aiRequestFailed
        }
    }
    
    func summarizeConversation(_ messages: [ChatMessage]) async throws -> String {
        guard !messages.isEmpty else {
            return "No conversation to summarize."
        }
        
        let conversationText = messages.map { message in
            let role = message.isUser ? "User" : "Assistant"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
        
        let prompt = """
        Please provide a brief summary of the following conversation:
        
        \(conversationText)
        
        Summary:
        """
        
        let request = AnalysisRequest(inputText: prompt, rubric: .general)
        
        do {
            let response = try await aiClient.analyze(request)
            return response.feedback
        } catch {
            throw ChatError.aiRequestFailed
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildChatPrompt(
        userMessage: String,
        session: Session,
        history: [ChatMessage]
    ) -> String {
        var prompt = """
        You are an interview coach assistant helping a candidate understand their interview analysis.
        
        ## Session Context
        
        Role: \(session.role ?? "Not specified")
        Rubric: \(session.rubricType.description)
        
        ## Original Interview Q&A
        
        \(session.inputText)
        
        ## Analysis Feedback
        
        \(session.outputFeedback)
        
        """
        
        // Add conversation history if available
        if !history.isEmpty {
            prompt += "\n## Previous Conversation\n\n"
            for message in history.suffix(5) { // Last 5 messages for context
                let role = message.isUser ? "User" : "Assistant"
                prompt += "\(role): \(message.content)\n\n"
            }
        }
        
        prompt += """
        
        ## User Question
        
        \(userMessage)
        
        ## Instructions
        
        Please provide a helpful, specific response based on the session context and analysis. 
        Be concise but thorough. Reference specific parts of the interview or feedback when relevant.
        If the question is about improving answers, provide concrete examples.
        """
        
        return prompt
    }
}

// MARK: - Mock Implementation

actor MockChatService: ChatService {
    var shouldFail = false
    var mockResponse = "This is a mock response to your question about the interview analysis."
    
    func sendMessage(
        _ message: String,
        session: Session,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        guard !shouldFail else {
            throw ChatError.aiRequestFailed
        }
        
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return mockResponse
    }
    
    func summarizeConversation(_ messages: [ChatMessage]) async throws -> String {
        guard !shouldFail else {
            throw ChatError.aiRequestFailed
        }
        
        return "This is a mock summary of the conversation."
    }
}
