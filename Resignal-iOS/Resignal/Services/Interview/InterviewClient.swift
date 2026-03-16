//
//  InterviewClient.swift
//  Resignal
//
//  Protocol defining the interview list client interface.
//

import Foundation

/// Errors that can occur when fetching interviews
enum InterviewClientError: Error, LocalizedError, Sendable {
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case rateLimited
    case unauthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Authentication required"
        case .notFound:
            return "Interview not found"
        }
    }
}

/// Protocol for fetching paginated interview lists from the backend.
/// All implementations must be actor-isolated or thread-safe.
protocol InterviewClient: Sendable {
    /// Fetches a paginated list of interviews for the current user.
    /// - Parameters:
    ///   - page: Page number (1-indexed)
    ///   - pageSize: Number of items per page (1–100)
    /// - Returns: The list response including interviews and pagination info
    /// - Throws: InterviewClientError on failure
    nonisolated func fetchInterviews(page: Int, pageSize: Int) async throws -> InterviewListResponse
    
    /// Fetches the full feedback details for a specific interview.
    /// - Parameter id: The interview ID
    /// - Returns: Structured feedback including the interview ID
    /// - Throws: InterviewClientError on failure
    nonisolated func fetchInterviewDetail(id: String) async throws -> StructuredFeedback
    
    /// Fetches the full interview transcript on demand.
    /// - Parameter id: The interview ID
    /// - Returns: The transcript response containing the interview ID and transcript text
    /// - Throws: InterviewClientError on failure
    nonisolated func fetchTranscript(id: String) async throws -> TranscriptResponse
}
