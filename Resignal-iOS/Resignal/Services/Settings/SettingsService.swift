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

// MARK: - AI Model

/// Represents the available AI model providers
enum AIModel: String, CaseIterable, Sendable {
    case DeepSeek = "DeepSeek"
    case Gemini = "Gemini"
    case OpenAI = "OpenAI"
    
    var displayName: String {
        switch self {
        case .DeepSeek: return "DeepSeek"
        case .Gemini: return "Gemini"
        case .OpenAI: return "OpenAI"
        }
    }
    
    /// The lowercase value sent in API request bodies (e.g. `"model": "gemini"`)
    var apiValue: String {
        switch self {
        case .DeepSeek: return "deepseek"
        case .Gemini: return "gemini"
        case .OpenAI: return "openai"
        }
    }
}

// MARK: - Audio API

/// Represents the available audio transcription APIs
enum AudioAPI: String, CaseIterable, Sendable {
    case apple = "apple"
    case openaiWhisper = "openaiWhisper"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .openaiWhisper: return "OpenAI Whisper"
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
    var aiModel: AIModel { get set }
    var audioAPI: AudioAPI { get set }
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
        static let aiModel = "aiModel"
        static let audioAPI = "audioAPI"
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
    
    var aiModel: AIModel {
        didSet {
            defaults.set(aiModel.rawValue, forKey: Keys.aiModel)
        }
    }
    
    var audioAPI: AudioAPI {
        didSet {
            defaults.set(audioAPI.rawValue, forKey: Keys.audioAPI)
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
        
        if let rawModel = defaults.string(forKey: Keys.aiModel),
           let model = AIModel(rawValue: rawModel) {
            self.aiModel = model
        } else {
            self.aiModel = .Gemini
        }
        
        if let rawAudioAPI = defaults.string(forKey: Keys.audioAPI),
           let audioAPI = AudioAPI(rawValue: rawAudioAPI) {
            self.audioAPI = audioAPI
        } else {
            self.audioAPI = .apple
        }
    }
    
}
