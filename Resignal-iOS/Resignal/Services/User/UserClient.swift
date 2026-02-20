//
//  UserClient.swift
//  Resignal
//
//  Protocol defining the user client interface for user registration.
//

import Foundation

/// Errors that can occur during user registration
enum UserClientError: Error, LocalizedError, Sendable {
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case alreadyRegistered
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .alreadyRegistered:
            return "User is already registered"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Response model for user registration
struct UserRegistrationResponse: Codable, Sendable {
    let success: Bool
    let message: String?
    
    init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

/// Protocol defining the user client interface
/// All implementations must be actor-isolated or thread-safe
protocol UserClient: Sendable {
    /// Registers a user with the backend
    /// - Returns: Registration response
    /// - Throws: UserClientError if registration fails
    nonisolated func registerUser() async throws -> UserRegistrationResponse
    
    /// Requests deletion of all server-side data associated with the current anonymous user.
    /// - Throws: UserClientError if the request fails
    nonisolated func deleteAllData() async throws
}
