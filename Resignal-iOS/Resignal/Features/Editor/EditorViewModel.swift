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
    private let attachmentService: AttachmentService
    private let featureAccessService: FeatureAccessServiceProtocol
    private let appReviewService: AppReviewServiceProtocol
    
    // Session data
    var inputText: String = ""
    var attachments: [SessionAttachment] = []
    private var audioURL: URL?
    
    // UI state
    var analysisState: ViewState<String> = .idle
    var analysisProgress: Double = 0
    var showAttachmentPicker: Bool = false
    
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
    
    // MARK: - Initialization
    
    init(
        aiClient: any AIClient,
        attachmentService: AttachmentService,
        featureAccessService: FeatureAccessServiceProtocol,
        appReviewService: AppReviewServiceProtocol,
        initialTranscript: String? = nil,
        audioURL: URL? = nil
    ) {
        self.aiClient = aiClient
        self.attachmentService = attachmentService
        self.featureAccessService = featureAccessService
        self.appReviewService = appReviewService
        self.audioURL = audioURL
        
        if let initialTranscript = initialTranscript, !initialTranscript.isEmpty {
            self.inputText = initialTranscript
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts the AI analysis and returns the server-generated interview ID
    func analyze() async -> String? {
        guard canAnalyze else { return nil }
        
        analysisState = .loading
        analysisProgress = 0
        
        let progressTask = Task {
            let totalSteps = 30
            let totalDuration: Double = 15.0
            
            for step in 1...totalSteps {
                let linearProgress = Double(step) / Double(totalSteps)
                let easedProgress = 1.0 - pow(1.0 - linearProgress, 2)
                analysisProgress = min(easedProgress * 0.95, 0.95)
                
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
            let imageAttachment = await prepareImageForAnalysis()
            let request = AnalysisRequest(inputText: inputText, image: imageAttachment)
            let response = try await aiClient.analyze(request)
            analysisResult = response.feedback
            
            let interviewId = response.interviewId ?? ""
            analysisState = .success(interviewId)
            featureAccessService.recordSessionCreation()
            
            appReviewService.recordSessionCompleted()
            if appReviewService.lifetimeSessionCount >= AppReviewConstants.sessionCountForAutoPrompt
                && appReviewService.shouldPromptReview() {
                appReviewService.hasPendingPrompt = true
            }
            
            return interviewId
            
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
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[EditorViewModel] \(message)")
        #endif
    }
    
    /// Prepares the first image attachment for API analysis
    private func prepareImageForAnalysis() async -> ImageAttachment? {
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
