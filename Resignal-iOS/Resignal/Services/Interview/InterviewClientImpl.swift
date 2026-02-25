//
//  InterviewClientImpl.swift
//  Resignal
//
//  Default implementation of InterviewClient that fetches interviews from the backend API.
//

import Foundation

/// Fetches paginated interview lists via the centralized APIClient.
actor InterviewClientImpl: InterviewClient {

    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Initialization

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - InterviewClient

    nonisolated func fetchInterviews(page: Int, pageSize: Int) async throws -> InterviewListResponse {
        try await performFetch(page: page, pageSize: pageSize)
    }

    nonisolated func fetchInterviewDetail(id: String) async throws -> StructuredFeedback {
        try await performFetchDetail(id: id)
    }

    nonisolated func fetchTranscript(id: String) async throws -> TranscriptResponse {
        try await performFetchTranscript(id: id)
    }

    // MARK: - Private

    private nonisolated func performFetch(page: Int, pageSize: Int) async throws -> InterviewListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]

        do {
            return try await apiClient.request(
                "/api/interviews",
                method: .get,
                queryItems: queryItems
            )
        } catch let error as APIError {
            throw mapToInterviewError(error)
        }
    }

    private nonisolated func performFetchDetail(id: String) async throws -> StructuredFeedback {
        do {
            return try await apiClient.request("/api/interviews/\(id)")
        } catch let error as APIError {
            throw mapToInterviewError(error)
        }
    }

    private nonisolated func performFetchTranscript(id: String) async throws -> TranscriptResponse {
        do {
            return try await apiClient.request("/api/interviews/\(id)/transcript")
        } catch let error as APIError {
            throw mapToInterviewError(error)
        }
    }

    private nonisolated func mapToInterviewError(_ error: APIError) -> InterviewClientError {
        switch error {
        case .unauthorized, .userNotFound:
            return .unauthorized
        case .notFound:
            return .notFound
        case .rateLimited:
            return .rateLimited
        case .networkError(let msg):
            return .networkError(msg)
        case .invalidResponse:
            return .invalidResponse
        case .decodingFailed:
            return .invalidResponse
        default:
            return .apiError(error.localizedDescription ?? "Unknown error")
        }
    }
}
