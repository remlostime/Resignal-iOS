//
//  EditorViewModel.swift
//  Resignal
//
//  ViewModel for the session editor/new session screen.
//

import Foundation
import SwiftUI

/// ViewModel managing the editor screen state and logic
@MainActor
@Observable
final class EditorViewModel: EditorViewModelProtocol {
    
    // MARK: - Properties
    
    private let aiClient: any AIClient
    private let sessionRepository: SessionRepositoryProtocol
    private let attachmentService: AttachmentService
    private let featureAccessService: FeatureAccessServiceProtocol
    
    // Session data
    var session: Session?
    var inputText: String = ""
    var attachments: [SessionAttachment] = []
    private var audioURL: URL?
    
    // UI state
    var analysisState: ViewState<Session> = .idle
    var analysisProgress: Double = 0
    var showAttachmentPicker: Bool = false
    var showPaywall: Bool = false
    
    // Analysis result
    var analysisResult: StructuredFeedback?
    
    // MARK: - Computed Properties
    
    var canAnalyze: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= ValidationConstants.minimumInputCharacters
    }
    
    var characterCountMessage: String {
        let count = inputText.trimmingCharacters(in: .whitespacesAndNewlines).count
        if count < ValidationConstants.minimumInputCharacters {
            return "\(ValidationConstants.minimumInputCharacters - count) more characters needed"
        }
        return "\(count) characters"
    }
    
    var isEditing: Bool {
        session != nil
    }
    
    var isAnalyzing: Bool {
        analysisState.isLoading
    }
    
    var errorMessage: String? {
        analysisState.error
    }
    
    var showError: Bool {
        get { analysisState.hasError }
        set { if !newValue { clearError() } }
    }
    
    /// Whether the user is on the free plan
    var isFreePlan: Bool {
        !featureAccessService.isPro
    }
    
    /// Message showing remaining free analyses (e.g. "2 of 3 free analyses remaining")
    var remainingAnalysesMessage: String? {
        guard isFreePlan else { return nil }
        let remaining = featureAccessService.remainingFreeAnalyses
        let max = featureAccessService.maxFreeAnalyses
        return "\(remaining) of \(max) free analyses remaining"
    }
    
    // MARK: - Initialization
    
    init(
        aiClient: any AIClient,
        sessionRepository: SessionRepositoryProtocol,
        attachmentService: AttachmentService,
        featureAccessService: FeatureAccessServiceProtocol,
        session: Session? = nil,
        initialTranscript: String? = nil,
        audioURL: URL? = nil
    ) {
        self.aiClient = aiClient
        self.sessionRepository = sessionRepository
        self.attachmentService = attachmentService
        self.featureAccessService = featureAccessService
        self.session = session
        self.audioURL = audioURL
        
        // Pre-populate from existing session or initial transcript
        if let session = session {
            self.inputText = session.inputText
            self.attachments = session.attachments
        } else if let initialTranscript = initialTranscript, !initialTranscript.isEmpty {
            self.inputText = initialTranscript
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts the AI analysis
    func analyze() async -> Session? {
        guard canAnalyze else { return nil }
        
        // Check if user has reached their free analysis limit
        if !featureAccessService.canAnalyze {
            showPaywall = true
            return nil
        }
        
        analysisState = .loading
        analysisProgress = 0
        
        // Simulate progress with ease-out curve over ~15 seconds
        let progressTask = Task {
            let totalSteps = 30
            let totalDuration: Double = 15.0  // seconds
            
            for step in 1...totalSteps {
                // Ease-out: faster at start, slower at end
                let linearProgress = Double(step) / Double(totalSteps)
                let easedProgress = 1.0 - pow(1.0 - linearProgress, 2)  // quadratic ease-out
                
                // Cap at 95% so it doesn't feel "stuck" if API takes longer
                analysisProgress = min(easedProgress * 0.95, 0.95)
                
                // Variable delay: shorter at start, longer at end
                let stepDuration = totalDuration / Double(totalSteps)
                try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
                
                if Task.isCancelled { break }
            }
        }
        
        defer {
            progressTask.cancel()
            analysisProgress = 1.0
        }
        
        do {
            // Prepare image attachment if available
            let imageAttachment = await prepareImageForAnalysis()
            
            let request = AnalysisRequest(inputText: inputText, image: imageAttachment)
            
            let response = try await aiClient.analyze(request)
            analysisResult = response.feedback
            
            // Save or update session
            let savedSession = try saveSession(with: response.feedback, interviewId: response.interviewId)
            analysisState = .success(savedSession)
            
            // Record analysis for free-tier usage tracking
            featureAccessService.recordAnalysis()
            
            return savedSession
            
        } catch let error as AIClientError {
            analysisState = .error(error.localizedDescription)
            debugLog("Analysis error: \(error)")
            return nil
        } catch {
            analysisState = .error("An unexpected error occurred. Please try again.")
            debugLog("Unexpected error: \(error)")
            return nil
        }
    }
    
    /// Cancels the ongoing analysis
    func cancelAnalysis() {
        aiClient.cancel()
        analysisState = .idle
        analysisProgress = 0
    }
    
    /// Saves the session without analysis (draft)
    func saveDraft() -> Session? {
        do {
            return try saveSession(with: nil)
        } catch {
            analysisState = .error("Failed to save draft: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clears any error state
    func clearError() {
        if analysisState.hasError {
            analysisState = .idle
        }
    }
    
    /// Adds an attachment
    func addAttachment(_ attachment: SessionAttachment) {
        attachments.append(attachment)
    }
    
    /// Removes an attachment
    func removeAttachment(_ attachment: SessionAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
    
    /// Toggles attachment picker
    func toggleAttachmentPicker() {
        showAttachmentPicker.toggle()
    }
    
    // MARK: - Private Methods
    
    private func saveSession(with feedback: StructuredFeedback?, interviewId: String? = nil) throws -> Session {
        // Use server-provided title if available
        let serverTitle = feedback?.title
        
        if let existingSession = session {
            // Update existing session
            existingSession.inputText = inputText
            existingSession.structuredFeedback = feedback
            existingSession.interviewId = interviewId
            existingSession.version += 1
            
            // Update title from server if session has no custom title
            if existingSession.title.isEmpty, let title = serverTitle {
                existingSession.title = title
            }
            
            // Save attachments
            for attachment in attachments {
                if !existingSession.attachments.contains(where: { $0.id == attachment.id }) {
                    try sessionRepository.saveAttachment(attachment, to: existingSession)
                }
            }
            
            try sessionRepository.update(existingSession, title: nil, tags: nil)
            return existingSession
        } else {
            // Create new session with server-provided title
            let newSession = Session(
                title: serverTitle ?? "",
                role: nil,
                inputText: inputText,
                structuredFeedback: feedback,
                rubric: .general,
                tags: [],
                audioFileURL: audioURL,
                attachments: attachments,
                interviewId: interviewId
            )
            
            try sessionRepository.save(newSession)
            session = newSession
            return newSession
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EditorViewModel] \(message)")
        #endif
    }
    
    /// Prepares the first image attachment for API analysis
    private func prepareImageForAnalysis() async -> ImageAttachment? {
        // Get the first image attachment
        guard let imageAttachment = attachments.first(where: { $0.attachmentType == .image }) else {
            return nil
        }
        
        do {
            let base64Data = try await attachmentService.getBase64Data(imageAttachment)
            let mimeType = await attachmentService.getMimeType(imageAttachment)
            
            return ImageAttachment(base64: base64Data, mimeType: mimeType)
        } catch {
            debugLog("Failed to prepare image for analysis: \(error)")
            return nil
        }
    }
}
