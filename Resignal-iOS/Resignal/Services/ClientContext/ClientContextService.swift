//
//  ClientContextService.swift
//  Resignal
//
//  Service for managing client context including persistent client ID and device metadata.
//

import Foundation
import Security
import UIKit

/// Protocol for client context management
/// Provides all metadata needed to identify a client in API requests.
protocol ClientContextServiceProtocol: Sendable {
    var clientId: String { get }
    var appVersion: String { get }
    var deviceModel: String { get }
    var platform: String { get }
}

/// Service that provides client context for API requests.
/// - Client ID: Persistent UUID stored in Keychain (survives app reinstalls)
/// - App Version: From bundle info
/// - Device Model: From UIDevice
/// - Platform: Constant "ios"
final class ClientContextService: ClientContextServiceProtocol, @unchecked Sendable {
    
    // MARK: - Constants
    
    private enum Constants {
        static let keychainService = "app.resignal.clientid"
        static let keychainAccount = "client_identifier"
    }
    
    // MARK: - Singleton
    
    static let shared = ClientContextService()
    
    // MARK: - Cached Values
    
    private var cachedClientId: String?
    private let lock = NSLock()
    
    // MARK: - ClientContextServiceProtocol
    
    /// Persistent client identifier stored in Keychain.
    /// Creates a new UUID on first access and persists it across app reinstalls.
    var clientId: String {
        lock.lock()
        defer { lock.unlock() }
        
        // Return cached value if available
        if let cached = cachedClientId {
            return cached
        }
        
        // Try to retrieve from Keychain
        if let existingId = retrieveFromKeychain() {
            cachedClientId = existingId
            return existingId
        }
        
        // Generate new UUID and store it
        let newId = UUID().uuidString
        saveToKeychain(newId)
        cachedClientId = newId
        return newId
    }
    
    /// App version string in format "major.minor.build" (e.g., "1.0.42")
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version).\(build)"
    }
    
    /// Device model identifier (e.g., "iPhone", "iPad")
    var deviceModel: String {
        DispatchQueue.main.sync {
            UIDevice.current.model
        }
    }
    
    /// Platform identifier
    var platform: String {
        "ios"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Private Keychain Methods
    
    private func retrieveFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let clientId = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return clientId
    }
    
    private func saveToKeychain(_ clientId: String) {
        guard let data = clientId.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
}
