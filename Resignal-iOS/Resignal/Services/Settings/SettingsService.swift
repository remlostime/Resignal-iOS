//
//  SettingsService.swift
//  Resignal
//
//  Service for managing app settings with UserDefaults.
//

import Foundation

// MARK: - API Environment

/// Represents the available API backend environments
enum APIEnvironment: String, CaseIterable, Sendable {
    case prod = "prod"
    case dev = "dev"
    
    var baseURL: String {
        switch self {
        case .prod: return "https://resignal-backend.vercel.app"
        case .dev: return "http://localhost:3000"
        }
    }
    
    var displayName: String {
        switch self {
        case .prod: return "Prod"
        case .dev: return "Dev"
        }
    }
}

/// Protocol defining settings service interface
@MainActor
protocol SettingsServiceProtocol: AnyObject, Sendable {
    var useMockAI: Bool { get set }
    var hasRegisteredUser: Bool { get set }
    var appVersion: String { get }
    var apiEnvironment: APIEnvironment { get set }
}

/// Service for managing app settings
@MainActor
@Observable
final class SettingsService: SettingsServiceProtocol {
    
    // MARK: - Keys
    
    private enum Keys {
        static let useMockAI = "useMockAI"
        static let hasRegisteredUser = "hasRegisteredUser"
        static let apiEnvironment = "apiEnvironment"
    }
    
    // MARK: - Properties
    
    private let defaults: UserDefaults
    
    var useMockAI: Bool {
        didSet {
            defaults.set(useMockAI, forKey: Keys.useMockAI)
        }
    }
    
    var hasRegisteredUser: Bool {
        didSet {
            defaults.set(hasRegisteredUser, forKey: Keys.hasRegisteredUser)
        }
    }
    
    var apiEnvironment: APIEnvironment {
        didSet {
            defaults.set(apiEnvironment.rawValue, forKey: Keys.apiEnvironment)
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
        self.hasRegisteredUser = defaults.object(forKey: Keys.hasRegisteredUser) as? Bool ?? false
        
        if let rawEnvironment = defaults.string(forKey: Keys.apiEnvironment),
           let environment = APIEnvironment(rawValue: rawEnvironment) {
            self.apiEnvironment = environment
        } else {
            self.apiEnvironment = .prod
        }
    }
    
}
