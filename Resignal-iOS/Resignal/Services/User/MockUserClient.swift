//
//  MockUserClient.swift
//  Resignal
//
//  Mock user client that returns deterministic responses for development and testing.
//

import Foundation

/// Mock user client for development and testing
/// Returns deterministic responses without requiring network access
actor MockUserClient: UserClient {
    
    // MARK: - Properties
    
    private let shouldSucceed: Bool
    private let delay: TimeInterval
    
    // MARK: - Initialization
    
    init(shouldSucceed: Bool = true, delay: TimeInterval = 0.5) {
        self.shouldSucceed = shouldSucceed
        self.delay = delay
    }
    
    // MARK: - UserClient Implementation
    
    nonisolated func registerUser() async throws -> UserRegistrationResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(delay))
        
        // Check for cancellation
        try Task.checkCancellation()
        
        if shouldSucceed {
            return UserRegistrationResponse(
                success: true,
                message: "Mock user registered successfully"
            )
        } else {
            throw UserClientError.apiError("Mock registration failed")
        }
    }
}
