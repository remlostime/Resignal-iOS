//
//  AIClient.swift
//  Resignal
//
//  Protocol defining the AI client interface for interview analysis.
//

import Foundation

/// Errors that can occur during AI analysis
enum AIClientError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case networkError(String)
    case apiError(String)
    case cancelled
    case unauthorized
    case rateLimited
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .cancelled:
            return "Analysis was cancelled"
        case .unauthorized:
            return "Invalid API key. Please check your settings."
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Request model for AI analysis
/// Nonisolated to allow use from any actor context
struct AnalysisRequest: Sendable {
    nonisolated let inputText: String

    nonisolated init(inputText: String) {
        self.inputText = inputText
    }
}

/// Response model for AI analysis
/// Nonisolated to allow use from any actor context
struct AnalysisResponse: Sendable {
    nonisolated let feedback: StructuredFeedback
    nonisolated let timestamp: Date

    nonisolated init(feedback: StructuredFeedback, timestamp: Date = Date()) {
        self.feedback = feedback
        self.timestamp = timestamp
    }
}

/// Protocol defining the AI client interface
/// All implementations must be actor-isolated or thread-safe
protocol AIClient: Sendable {
    /// Analyzes interview Q&A and returns structured feedback
    /// - Parameter request: The analysis request containing input text and context
    /// - Returns: Analysis response with structured feedback
    /// - Throws: AIClientError if analysis fails
    nonisolated func analyze(_ request: AnalysisRequest) async throws -> AnalysisResponse

    /// Cancels any ongoing analysis
    nonisolated func cancel()

    /// Returns true if an analysis is currently in progress
    nonisolated var isAnalyzing: Bool { get async }
}

