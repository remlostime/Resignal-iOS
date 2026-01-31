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
        // Note: This uses the analysis endpoint which returns StructuredFeedback.
        // For chat, we use the summary field as the response text.
        // TODO: Consider a dedicated chat endpoint for plain text responses.
        let request = AnalysisRequest(inputText: prompt)
        
        do {
            let response = try await aiClient.analyze(request)
            return formatChatResponse(response.feedback)
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
        
        let request = AnalysisRequest(inputText: prompt)
        
        do {
            let response = try await aiClient.analyze(request)
            return formatChatResponse(response.feedback)
        } catch {
            throw ChatError.aiRequestFailed
        }
    }
    
    /// Formats StructuredFeedback into a chat-friendly text response
    private func formatChatResponse(_ feedback: StructuredFeedback) -> String {
        // For chat responses, combine relevant parts into readable text
        var parts: [String] = []
        
        if !feedback.summary.isEmpty {
            parts.append(feedback.summary)
        }
        
        if !feedback.keyObservations.isEmpty {
            parts.append("Key observations:\n" + feedback.keyObservations.map { "• \($0)" }.joined(separator: "\n"))
        }
        
        return parts.isEmpty ? "I couldn't generate a response." : parts.joined(separator: "\n\n")
    }
    
    // MARK: - Private Helpers
    
    private func buildChatPrompt(
        userMessage: String,
        session: Session,
        history: [ChatMessage]
    ) -> String {
        let feedbackContext = formatFeedbackForPrompt(session.structuredFeedback)
        
        var prompt = """
        You are an interview coach assistant helping a candidate understand their interview analysis.
        
        ## Session Context
        
        Role: \(session.role ?? "Not specified")
        Rubric: \(session.rubricType.description)
        
        ## Original Interview Q&A
        
        \(session.inputText)
        
        ## Analysis Feedback
        
        \(feedbackContext)
        
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
    
    private func formatFeedbackForPrompt(_ feedback: StructuredFeedback?) -> String {
        guard let feedback = feedback else {
            return "No analysis available yet."
        }
        
        var result = """
        Summary: \(feedback.summary)
        
        Strengths:
        \(feedback.strengths.map { "- \($0)" }.joined(separator: "\n"))
        
        Areas for Improvement:
        \(feedback.improvement.map { "- \($0)" }.joined(separator: "\n"))
        
        Hiring Signal: \(feedback.hiringSignal)
        
        Key Observations:
        \(feedback.keyObservations.map { "- \($0)" }.joined(separator: "\n"))
        """
        
        return result
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
