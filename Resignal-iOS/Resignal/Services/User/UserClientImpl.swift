//
//  UserClientImpl.swift
//  Resignal
//
//  Default implementation of UserClient that integrates with Resignal backend API.
//

import Foundation

/// Default user client implementation
/// Integrates with the Resignal backend at https://resignal-backend.vercel.app
actor UserClientImpl: UserClient {
    
    // MARK: - Properties
    
    private let baseURL: String
    private let clientContextService: ClientContextServiceProtocol
    
    // MARK: - Initialization
    
    init(
        baseURL: String = "https://resignal-backend.vercel.app",
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.clientContextService = clientContextService
    }
    
    // MARK: - UserClient Implementation
    
    nonisolated func registerUser() async throws -> UserRegistrationResponse {
        try await performRegistration()
    }
    
    // MARK: - Private Methods
    
    private func performRegistration() async throws -> UserRegistrationResponse {
        // Create user object with client context
        let user = User(
            userId: clientContextService.clientId,
            email: "user@resignal.app", // Placeholder email
            plan: .free // Always free for now
        )
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/api/users") else {
            throw UserClientError.networkError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(clientContextService.clientId, forHTTPHeaderField: "x-client-id")
        urlRequest.setValue(clientContextService.appVersion, forHTTPHeaderField: "x-client-version")
        urlRequest.setValue(clientContextService.platform, forHTTPHeaderField: "x-client-platform")
        urlRequest.setValue(clientContextService.deviceModel, forHTTPHeaderField: "x-device-model")
        urlRequest.timeoutInterval = 30
        
        // Encode request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            urlRequest.httpBody = try encoder.encode(user)
        } catch {
            throw UserClientError.networkError("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw UserClientError.networkError("Request failed: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserClientError.invalidResponse
        }
        
        // Handle response
        switch httpResponse.statusCode {
        case 200...299:
            // Try to decode response if available
            let decoder = JSONDecoder()
            if let registrationResponse = try? decoder.decode(UserRegistrationResponse.self, from: data) {
                return registrationResponse
            }
            // If no response body or can't decode, return success
            return UserRegistrationResponse(success: true, message: "User registered successfully")
            
        case 409:
            // User already registered
            throw UserClientError.alreadyRegistered
            
        case 400...499:
            // Client error
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw UserClientError.apiError("Client error (HTTP \(httpResponse.statusCode)): \(errorMessage)")
            }
            throw UserClientError.apiError("Client error (HTTP \(httpResponse.statusCode))")
            
        case 500...599:
            // Server error
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw UserClientError.apiError("Server error (HTTP \(httpResponse.statusCode)): \(errorMessage)")
            }
            throw UserClientError.apiError("Server error (HTTP \(httpResponse.statusCode))")
            
        default:
            throw UserClientError.apiError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
}
