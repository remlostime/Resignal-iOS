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
    
    private let _aiClientFactory: () -> any AIClient
    
    var aiClient: any AIClient {
        _aiClientFactory()
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize SwiftData model container
        do {
            let schema = Schema([Session.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
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
        
        // Create AI client factory that checks settings each time
        self._aiClientFactory = { [settings] in
            if settings.useMockAI {
                return MockAIClient()
            } else {
                return OpenAICompatibleClient(
                    baseURL: settings.apiBaseURL,
                    apiKey: settings.apiKey
                )
            }
        }
    }
    
    /// Creates a container for previews and testing
    static func preview() -> DependencyContainer {
        let container = DependencyContainer()
        return container
    }
}

