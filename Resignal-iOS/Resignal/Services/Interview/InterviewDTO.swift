//
//  InterviewDTO.swift
//  Resignal
//
//  Data transfer objects for the GET /api/interviews endpoint.
//

import Foundation

/// Top-level response from GET /api/interviews
struct InterviewListResponse: Codable, Sendable, Equatable {
    let interviews: [InterviewDTO]
    let pagination: PaginationInfo
}

/// A single interview summary returned by the list endpoint
struct InterviewDTO: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String?
    let summary: String?
    let createdAt: Date

    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Interview - \(formatter.string(from: createdAt))"
    }
}

/// Pagination metadata included in list responses
struct PaginationInfo: Codable, Sendable, Equatable {
    let currentPage: Int
    let pageSize: Int
    let totalPages: Int
    let totalItems: Int
}
