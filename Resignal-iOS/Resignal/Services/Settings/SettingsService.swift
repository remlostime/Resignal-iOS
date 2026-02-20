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
    var hasSeenOnboarding: Bool { get set }
    var hasAcceptedTerms: Bool { get set }
    var hasSeenRecordingNotice: Bool { get set }
    var appVersion: String { get }
    var apiEnvironment: APIEnvironment { get set }
    var aiModel: AIModel { get set }
    var audioAPI: AudioAPI { get set }
    
    #if DEBUG
    /// Whether mock subscription mode is enabled (overrides real StoreKit status)
    var mockSubscriptionEnabled: Bool { get set }
    /// The mock plan to use when mockSubscriptionEnabled is true
    var mockPlan: Plan { get set }
    #endif
}

/// Service for managing app settings
@MainActor
@Observable
final class SettingsService: SettingsServiceProtocol {
    
    // MARK: - Keys
    
    private enum Keys {
        static let useMockAI = "useMockAI"
        static let hasRegisteredUser = "hasRegisteredUser"
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasAcceptedTerms = "hasAcceptedTerms"
        static let hasSeenRecordingNotice = "hasSeenRecordingNotice"
        static let apiEnvironment = "apiEnvironment"
        static let aiModel = "aiModel"
        static let audioAPI = "audioAPI"
        #if DEBUG
        static let mockSubscriptionEnabled = "mockSubscriptionEnabled"
        static let mockPlan = "mockPlan"
        #endif
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
    
    var hasSeenOnboarding: Bool {
        didSet {
            defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding)
        }
    }
    
    var hasAcceptedTerms: Bool {
        didSet {
            defaults.set(hasAcceptedTerms, forKey: Keys.hasAcceptedTerms)
        }
    }
    
    var hasSeenRecordingNotice: Bool {
        didSet {
            defaults.set(hasSeenRecordingNotice, forKey: Keys.hasSeenRecordingNotice)
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
    
    #if DEBUG
    var mockSubscriptionEnabled: Bool {
        didSet {
            defaults.set(mockSubscriptionEnabled, forKey: Keys.mockSubscriptionEnabled)
        }
    }
    
    var mockPlan: Plan {
        didSet {
            defaults.set(mockPlan.rawValue, forKey: Keys.mockPlan)
        }
    }
    #endif
    
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
        self.hasSeenOnboarding = defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false
        self.hasAcceptedTerms = defaults.object(forKey: Keys.hasAcceptedTerms) as? Bool ?? false
        self.hasSeenRecordingNotice = defaults.object(forKey: Keys.hasSeenRecordingNotice) as? Bool ?? false
        
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
        
        #if DEBUG
        self.mockSubscriptionEnabled = defaults.object(forKey: Keys.mockSubscriptionEnabled) as? Bool ?? false
        if let rawPlan = defaults.string(forKey: Keys.mockPlan),
           let plan = Plan(rawValue: rawPlan) {
            self.mockPlan = plan
        } else {
            self.mockPlan = .free
        }
        #endif
    }
    
}
