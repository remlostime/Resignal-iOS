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
    var liveActivityService: LiveActivityService { get }
    var subscriptionService: SubscriptionServiceProtocol { get }
    var featureAccessService: FeatureAccessServiceProtocol { get }
    var audioUploadService: AudioUploadService { get }
    var audioCacheService: AudioCacheService { get }
    var interviewClient: any InterviewClient { get }
    var identityManager: IdentityManagerProtocol { get }
    var apiClient: APIClientProtocol { get }
    var billingClient: BillingClientProtocol { get }
    var appReviewService: AppReviewServiceProtocol { get }
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
    let liveActivityService: LiveActivityService
    let subscriptionService: SubscriptionServiceProtocol
    let featureAccessService: FeatureAccessServiceProtocol
    let audioUploadService: AudioUploadService
    let audioCacheService: AudioCacheService
    let interviewClient: any InterviewClient
    let identityManager: IdentityManagerProtocol
    let apiClient: APIClientProtocol
    let billingClient: BillingClientProtocol
    let appReviewService: AppReviewServiceProtocol
    private let isPreview: Bool
    
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
        
        let settings = SettingsService()
        self.settingsService = settings
        
        let baseURL = settings.apiEnvironment.baseURL
        let aiModelValue = settings.aiModel.apiValue
        
        if isPreview {
            let mockIdentity = MockIdentityManager()
            self.identityManager = mockIdentity
            let mockAPI = MockAPIClient()
            self.apiClient = mockAPI
            self.billingClient = MockBillingClient()
            
            self.recordingService = MockRecordingService()
            self.transcriptionService = MockTranscriptionService()
            self.attachmentService = MockAttachmentService()
            self.chatService = MockChatService()
            self.liveActivityService = MockLiveActivityService()
            self.audioUploadService = MockAudioUploadService()
            self.audioCacheService = MockAudioCacheService()
            self.interviewClient = MockInterviewClient()
            #if DEBUG
            let subscription = MockSubscriptionService()
            self.subscriptionService = subscription
            #else
            let subscription = SubscriptionService(billingClient: MockBillingClient())
            self.subscriptionService = subscription
            #endif
        } else {
            let keychain = KeychainService()
            let identity = IdentityManager(keychainService: keychain)
            self.identityManager = identity
            
            let api = APIClientImpl(baseURL: baseURL, identityManager: identity)
            self.apiClient = api
            
            let billing = BillingClientImpl(apiClient: api)
            self.billingClient = billing
            
            self.recordingService = RecordingServiceImpl()
            let vocabularyProvider = ContextualVocabularyProviderImpl()
            self.transcriptionService = TranscriptionServiceImpl(vocabularyProvider: vocabularyProvider)
            self.attachmentService = AttachmentServiceImpl()
            self.chatService = ChatServiceImpl(model: aiModelValue, apiClient: api)
            self.liveActivityService = LiveActivityServiceImpl()
            self.audioUploadService = AudioUploadServiceImpl(baseURL: baseURL, identityManager: identity)
            self.audioCacheService = AudioCacheServiceImpl()
            self.interviewClient = InterviewClientImpl(apiClient: api)
            let subscription = SubscriptionService(billingClient: billing)
            self.subscriptionService = subscription
        }
        
        self.featureAccessService = FeatureAccessService(
            subscriptionService: self.subscriptionService,
            settingsService: settings
        )
        
        self.appReviewService = isPreview
            ? MockAppReviewService()
            : AppReviewService()
    }
    
    // MARK: - Private Methods
    
    private func createAIClient() -> any AIClient {
        let aiModelValue = settingsService.aiModel.apiValue
        return ResignalAIClient(model: aiModelValue, apiClient: apiClient)
    }
    
    /// Creates a container for previews and testing with in-memory storage
    static func preview() -> DependencyContainer {
        DependencyContainer(isPreview: true)
    }
}
