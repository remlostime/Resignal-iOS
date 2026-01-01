//
//  SettingsService.swift
//  Resignal
//
//  Service for managing app settings with UserDefaults and Keychain.
//

import Foundation
import Security

/// Protocol defining settings service interface
@MainActor
protocol SettingsServiceProtocol: AnyObject, Sendable {
    var useMockAI: Bool { get set }
    var apiBaseURL: String { get set }
    var apiKey: String { get set }
    var aiModel: String { get set }
    var appVersion: String { get }
}

/// Service for managing app settings
@MainActor
@Observable
final class SettingsService: SettingsServiceProtocol {
    
    // MARK: - Keys
    
    private enum Keys {
        static let useMockAI = "useMockAI"
        static let apiBaseURL = "apiBaseURL"
        static let aiModel = "aiModel"
        static let apiKeyService = "com.resignal.apikey"
    }
    
    // MARK: - Default Values
    
    private enum Defaults {
        static let apiBaseURL = "https://api.openai.com/v1"
        static let aiModel = "gpt-4o-mini"
    }
    
    // MARK: - Properties
    
    private let defaults: UserDefaults
    
    var useMockAI: Bool {
        didSet {
            defaults.set(useMockAI, forKey: Keys.useMockAI)
        }
    }
    
    var apiBaseURL: String {
        didSet {
            defaults.set(apiBaseURL, forKey: Keys.apiBaseURL)
        }
    }
    
    var apiKey: String {
        didSet {
            saveAPIKeyToKeychain(apiKey)
        }
    }
    
    var aiModel: String {
        didSet {
            defaults.set(aiModel, forKey: Keys.aiModel)
        }
    }
    
    // MARK: - Computed Properties
    
    /// App version string
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    // MARK: - Initialization
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Load settings
        self.useMockAI = defaults.object(forKey: Keys.useMockAI) as? Bool ?? true
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? Defaults.apiBaseURL
        self.aiModel = defaults.string(forKey: Keys.aiModel) ?? Defaults.aiModel
        self.apiKey = Self.loadAPIKeyFromKeychain() ?? ""
    }
    
    // MARK: - Keychain Methods
    
    private func saveAPIKeyToKeychain(_ key: String) {
        let data = Data(key.utf8)
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Don't save empty keys
        guard !key.isEmpty else { return }
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("Failed to save API key to Keychain: \(status)")
        }
    }
    
    private static func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    // MARK: - Debug Logging
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SettingsService] \(message)")
        #endif
    }
}
