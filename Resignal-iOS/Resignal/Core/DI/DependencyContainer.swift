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
    var recordingService: RecordingService { get }
    var transcriptionService: TranscriptionService { get }
    var attachmentService: AttachmentService { get }
    var chatService: ChatService { get }
    var userClient: any UserClient { get }
}

/// Main dependency container that provides all app dependencies
@MainActor
@Observable
final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Properties
    
    let modelContainer: ModelContainer
    let settingsService: SettingsServiceProtocol
    let sessionRepository: SessionRepositoryProtocol
    let recordingService: RecordingService
    let transcriptionService: TranscriptionService
    let attachmentService: AttachmentService
    private let _chatService: ChatService
    let userClient: any UserClient
    private let isPreview: Bool
    
    // Cached AI client with invalidation tracking
    private var _cachedAIClient: (any AIClient)?
    private var _lastUseMockAI: Bool?
    
    var aiClient: any AIClient {
        let settings = settingsService
        let currentUseMock = settings.useMockAI
        
        // Check if we need to recreate the client
        let needsRecreation = _cachedAIClient == nil ||
            _lastUseMockAI != currentUseMock
        
        if needsRecreation {
            _cachedAIClient = createAIClient()
            _lastUseMockAI = currentUseMock
        }
        
        return _cachedAIClient!
    }
    
    var chatService: ChatService {
        _chatService
    }
    
    // MARK: - Initialization
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        
        // Initialize SwiftData model container
        do {
            let schema = Schema([
                Session.self,
                SessionAttachment.self,
                ChatMessage.self
            ])
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
        
        // Initialize new services
        if isPreview {
            self.recordingService = MockRecordingService()
            self.transcriptionService = MockTranscriptionService()
            self.attachmentService = MockAttachmentService()
            self._chatService = MockChatService()
            self.userClient = MockUserClient()
        } else {
            self.recordingService = RecordingServiceImpl()
            self.transcriptionService = TranscriptionServiceImpl()
            self.attachmentService = AttachmentServiceImpl()
            // ChatService will use the AI client from this container
            // We create a mock initially and will replace it with real one after init
            self._chatService = MockChatService()
            self.userClient = UserClientImpl()
        }
    }
    
    /// Initialize ChatService with real AI client (call after container is created)
    func initializeChatService() {
        if !isPreview {
            // In production, we'd replace the mock with real implementation
            // For now, the mock will work for both cases since ChatServiceImpl
            // will be created on-demand by ViewModels using container.aiClient
        }
    }
    
    // MARK: - Private Methods
    
    private func createAIClient() -> any AIClient {
        ResignalAIClient()
    }
    
    /// Creates a container for previews and testing with in-memory storage
    static func preview() -> DependencyContainer {
        DependencyContainer(isPreview: true)
    }
}
