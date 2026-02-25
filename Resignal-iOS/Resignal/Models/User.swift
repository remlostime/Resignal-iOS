//
//  User.swift
//  Resignal
//
//  Auth response models and shared API error types.
//

import Foundation

// MARK: - Plan

enum Plan: String, Codable, Sendable {
    case free
    case pro
}

// MARK: - Auth Response

struct AuthResponse: Codable, Sendable {
    let token: String
    let user: AuthUser
}

struct AuthUser: Codable, Sendable {
    let id: String
    let isPro: Bool
}

// MARK: - Standardized API Error Response

struct APIErrorResponse: Decodable, Sendable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Decodable, Sendable {
    let code: String
    let message: String
}

// MARK: - API Error

enum APIError: LocalizedError, Sendable {
    case unauthorized
    case userNotFound
    case proRequired
    case rateLimited
    case invalidInput(String)
    case notFound
    case internalError(String)
    case networkError(String)
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please try again."
        case .userNotFound:
            return "User not found."
        case .proRequired:
            return "An active Pro subscription is required."
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .invalidInput(let message):
            return message
        case .notFound:
            return "Resource not found."
        case .internalError(let message):
            return "Server error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        case .decodingFailed(let message):
            return "Failed to parse response: \(message)"
        }
    }

    static func from(code: String, message: String) -> APIError {
        switch code {
        case "UNAUTHORIZED": return .unauthorized
        case "USER_NOT_FOUND": return .userNotFound
        case "PRO_REQUIRED": return .proRequired
        case "RATE_LIMITED": return .rateLimited
        case "INVALID_INPUT": return .invalidInput(message)
        case "NOT_FOUND": return .notFound
        case "INTERNAL_ERROR": return .internalError(message)
        default: return .internalError(message)
        }
    }
}
