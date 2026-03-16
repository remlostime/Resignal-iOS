//
//  IdentityManager.swift
//  Resignal
//
//  Manages anonymous identity and JWT authentication.
//  Stores anonymousId and JWT securely in Keychain.
//  Handles registration with POST /api/auth/register.
//

import Foundation
import UIKit

// MARK: - Protocol

protocol IdentityManagerProtocol: Sendable {
    var currentToken: String? { get }
    var anonymousId: String { get }
    var isAuthenticated: Bool { get }
    var appVersion: String { get }
    var deviceModel: String { get }
    var platform: String { get }

    func register(baseURL: String) async throws
    func clearToken()
}

// MARK: - Implementation

final class IdentityManager: IdentityManagerProtocol, @unchecked Sendable {

    // MARK: - Constants

    private enum Keys {
        static let anonymousId = "anonymous_id"
        static let jwtToken = "jwt_token"
    }

    // MARK: - Dependencies

    private let keychainService: KeychainServiceProtocol

    // MARK: - Cached State

    private var cachedAnonymousId: String?
    private var cachedToken: String?
    private let lock = NSLock()

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol = KeychainService()) {
        self.keychainService = keychainService
        self.cachedToken = keychainService.loadString(forKey: Keys.jwtToken)
        self.cachedAnonymousId = keychainService.loadString(forKey: Keys.anonymousId)
    }

    // MARK: - IdentityManagerProtocol

    var currentToken: String? {
        lock.lock()
        defer { lock.unlock() }

        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "jwtTokenOverride"),
           !override.isEmpty {
            return override
        }
        #endif

        return cachedToken
    }

    var anonymousId: String {
        lock.lock()
        defer { lock.unlock() }

        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "clientIdOverride"),
           !override.isEmpty {
            return override
        }
        #endif

        if let cached = cachedAnonymousId {
            return cached
        }

        let newId = UUID().uuidString
        try? keychainService.saveString(newId, forKey: Keys.anonymousId)
        cachedAnonymousId = newId
        return newId
    }

    var isAuthenticated: Bool {
        currentToken != nil
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version).\(build)"
    }

    var deviceModel: String {
        if Thread.isMainThread {
            return UIDevice.current.model
        } else {
            return DispatchQueue.main.sync {
                UIDevice.current.model
            }
        }
    }

    var platform: String { "ios" }

    func register(baseURL: String) async throws {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(trimmedBase)/api/auth/register") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: String] = ["anonymousId": anonymousId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            try storeToken(authResponse.token)

        case 429:
            throw AuthError.rateLimited

        default:
            if let errorBody = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AuthError.serverError(errorBody.error.message)
            }
            throw AuthError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }

    func clearToken() {
        lock.lock()
        defer { lock.unlock() }
        keychainService.delete(forKey: Keys.jwtToken)
        cachedToken = nil
    }

    // MARK: - Private

    private func storeToken(_ token: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try keychainService.saveString(token, forKey: Keys.jwtToken)
        cachedToken = token
    }
}

// MARK: - Mock

final class MockIdentityManager: IdentityManagerProtocol, @unchecked Sendable {
    var currentToken: String? = "mock-jwt-token"
    var anonymousId: String = UUID().uuidString
    var isAuthenticated: Bool { currentToken != nil }
    var appVersion: String = "1.0.0"
    var deviceModel: String = "iPhone"
    var platform: String = "ios"

    var registerCallCount = 0
    var shouldFailRegister = false

    func register(baseURL: String) async throws {
        registerCallCount += 1
        if shouldFailRegister {
            throw AuthError.serverError("Mock registration failure")
        }
        currentToken = "mock-jwt-token-\(registerCallCount)"
    }

    func clearToken() {
        currentToken = nil
    }
}

// MARK: - Errors

enum AuthError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case rateLimited
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid registration URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let message):
            return message
        }
    }
}
