//
//  DependencyContainer.swift
//  Resignal
//
//  Dependency injection container using protocol-based design.
//

import Foundation
import Observation

/// Protocol defining the dependency container interface
@MainActor
protocol DependencyContainerProtocol {
    var aiClient: any AIClient { get }
    var settingsService: SettingsServiceProtocol { get }
    var recordingService: RecordingService { get }
    var transcriptionService: TranscriptionService { get }
    var attachmentService: AttachmentService { get }
    var chatService: ChatService { get }
    var userClient: any UserClient { get }
    var liveActivityService: LiveActivityService { get }
    var subscriptionService: SubscriptionServiceProtocol { get }
    var featureAccessService: FeatureAccessServiceProtocol { get }
    var audioUploadService: AudioUploadService { get }
    var interviewClient: any InterviewClient { get }
}

/// Main dependency container that provides all app dependencies
@MainActor
@Observable
final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Properties
    
    let settingsService: SettingsServiceProtocol
    let recordingService: RecordingService
    let transcriptionService: TranscriptionService
    let attachmentService: AttachmentService
    let chatService: ChatService
    let userClient: any UserClient
    let liveActivityService: LiveActivityService
    let subscriptionService: SubscriptionServiceProtocol
    let featureAccessService: FeatureAccessServiceProtocol
    let audioUploadService: AudioUploadService
    let interviewClient: any InterviewClient
    private let isPreview: Bool
    
    // Cached AI client with invalidation tracking (for useMockAI toggle)
    private var _cachedAIClient: (any AIClient)?
    private var _lastUseMockAI: Bool?
    
    var aiClient: any AIClient {
        let currentUseMock = settingsService.useMockAI
        
        let needsRecreation = _cachedAIClient == nil
            || _lastUseMockAI != currentUseMock
        
        if needsRecreation {
            _cachedAIClient = createAIClient()
            _lastUseMockAI = currentUseMock
        }
        
        return _cachedAIClient!
    }
    
    // MARK: - Initialization
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        
        // Initialize services
        let settings = SettingsService()
        self.settingsService = settings
        
        let baseURL = settings.apiEnvironment.baseURL
        let aiModelValue = settings.aiModel.apiValue
        if isPreview {
            self.recordingService = MockRecordingService()
            self.transcriptionService = MockTranscriptionService()
            self.attachmentService = MockAttachmentService()
            self.chatService = MockChatService()
            self.userClient = MockUserClient()
            self.liveActivityService = MockLiveActivityService()
            self.audioUploadService = MockAudioUploadService()
            self.interviewClient = MockInterviewClient()
            #if DEBUG
            let subscription = MockSubscriptionService()
            self.subscriptionService = subscription
            #else
            let subscription = SubscriptionService()
            self.subscriptionService = subscription
            #endif
        } else {
            self.recordingService = RecordingServiceImpl()
            let vocabularyProvider = ContextualVocabularyProviderImpl()
            self.transcriptionService = TranscriptionServiceImpl(vocabularyProvider: vocabularyProvider)
            self.attachmentService = AttachmentServiceImpl()
            self.chatService = ChatServiceImpl(baseURL: baseURL, model: aiModelValue)
            self.userClient = UserClientImpl(baseURL: baseURL)
            self.liveActivityService = LiveActivityServiceImpl()
            self.audioUploadService = AudioUploadServiceImpl(baseURL: baseURL)
            self.interviewClient = InterviewClientImpl(baseURL: baseURL)
            let subscription = SubscriptionService()
            self.subscriptionService = subscription
        }
        
        self.featureAccessService = FeatureAccessService(
            subscriptionService: self.subscriptionService,
            settingsService: settings
        )
    }
    
    // MARK: - Private Methods
    
    private func createAIClient() -> any AIClient {
        let baseURL = settingsService.apiEnvironment.baseURL
        let aiModelValue = settingsService.aiModel.apiValue
        return ResignalAIClient(baseURL: baseURL, model: aiModelValue)
    }
    
    /// Creates a container for previews and testing with in-memory storage
    static func preview() -> DependencyContainer {
        DependencyContainer(isPreview: true)
    }
}
