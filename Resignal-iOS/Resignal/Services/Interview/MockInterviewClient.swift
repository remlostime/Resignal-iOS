//
//  MockInterviewClient.swift
//  Resignal
//
//  Mock interview client that returns deterministic responses for development and testing.
//

import Foundation

/// Mock interview client for previews and tests
actor MockInterviewClient: InterviewClient {

    // MARK: - Properties

    private let shouldSucceed: Bool
    private let delay: TimeInterval

    // MARK: - Initialization

    init(shouldSucceed: Bool = true, delay: TimeInterval = 0.5) {
        self.shouldSucceed = shouldSucceed
        self.delay = delay
    }

    // MARK: - InterviewClient

    nonisolated func fetchInterviews(page: Int, pageSize: Int) async throws -> InterviewListResponse {
        try await Task.sleep(for: .seconds(delay))
        try Task.checkCancellation()

        if shouldSucceed {
            return InterviewListResponse(
                interviews: Self.sampleInterviews,
                pagination: PaginationInfo(
                    currentPage: page,
                    pageSize: pageSize,
                    totalPages: 1,
                    totalItems: Self.sampleInterviews.count
                )
            )
        } else {
            throw InterviewClientError.apiError("Mock fetch failed")
        }
    }

    // MARK: - Sample Data

    private static let sampleInterviews: [InterviewDTO] = [
        InterviewDTO(
            id: "550e8400-e29b-41d4-a716-446655440000",
            title: "Senior iOS Engineer Interview",
            summary: "Candidate demonstrated strong Swift and SwiftUI skills with practical examples.",
            createdAt: Date().addingTimeInterval(-3600)
        ),
        InterviewDTO(
            id: "550e8400-e29b-41d4-a716-446655440001",
            title: "Product Manager Screen",
            summary: "Good product sense but could improve on metrics-driven decision making.",
            createdAt: Date().addingTimeInterval(-86400)
        ),
        InterviewDTO(
            id: "550e8400-e29b-41d4-a716-446655440002",
            title: nil,
            summary: nil,
            createdAt: Date().addingTimeInterval(-172800)
        )
    ]
}
