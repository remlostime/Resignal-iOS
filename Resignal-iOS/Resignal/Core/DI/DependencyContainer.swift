//
//  DependencyContainer.swift
//  Resignal
//
//  Dependency injection container using protocol-based design.
//

import Foundation
import SwiftData
import Observation

/// Protocol defining the dependency container interface
@MainActor
protocol DependencyContainerProtocol {
    var aiClient: any AIClient { get }
    var settingsService: SettingsServiceProtocol { get }
    var sessionRepository: SessionRepositoryProtocol { get }
}

/// Main dependency container that provides all app dependencies
@MainActor
@Observable
final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Properties
    
    let modelContainer: ModelContainer
    let settingsService: SettingsServiceProtocol
    let sessionRepository: SessionRepositoryProtocol
    
    // Cached AI client with invalidation tracking
    private var _cachedAIClient: (any AIClient)?
    private var _lastUseMockAI: Bool?
    private var _lastAPIKey: String?
    private var _lastBaseURL: String?
    private var _lastModel: String?
    
    var aiClient: any AIClient {
        let settings = settingsService
        let currentUseMock = settings.useMockAI
        let currentAPIKey = settings.apiKey
        let currentBaseURL = settings.apiBaseURL
        let currentModel = settings.aiModel
        
        // Check if we need to recreate the client
        let needsRecreation = _cachedAIClient == nil ||
            _lastUseMockAI != currentUseMock ||
            _lastAPIKey != currentAPIKey ||
            _lastBaseURL != currentBaseURL ||
            _lastModel != currentModel
        
        if needsRecreation {
            _cachedAIClient = createAIClient()
            _lastUseMockAI = currentUseMock
            _lastAPIKey = currentAPIKey
            _lastBaseURL = currentBaseURL
            _lastModel = currentModel
        }
        
        return _cachedAIClient!
    }
    
    // MARK: - Initialization
    
    init(isPreview: Bool = false) {
        // Initialize SwiftData model container
        do {
            let schema = Schema([Session.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isPreview
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Initialize services
        let settings = SettingsService()
        self.settingsService = settings
        self.sessionRepository = SessionRepository(modelContext: modelContainer.mainContext)
    }
    
    // MARK: - Private Methods
    
    private func createAIClient() -> any AIClient {
        if settingsService.useMockAI {
            return MockAIClient()
        } else {
            return OpenAICompatibleClient(
                baseURL: settingsService.apiBaseURL,
                apiKey: settingsService.apiKey,
                model: settingsService.aiModel
            )
        }
    }
    
    /// Creates a container for previews and testing with in-memory storage
    static func preview() -> DependencyContainer {
        DependencyContainer(isPreview: true)
    }
}
