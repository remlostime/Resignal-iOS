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
    
    // Session data
    var session: Session?
    var inputText: String = ""
    var attachments: [SessionAttachment] = []
    private var audioURL: URL?
    
    // UI state
    var analysisState: ViewState<Session> = .idle
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
    
    // MARK: - Initialization
    
    init(
        aiClient: any AIClient,
        sessionRepository: SessionRepositoryProtocol,
        session: Session? = nil,
        initialTranscript: String? = nil,
        audioURL: URL? = nil
    ) {
        self.aiClient = aiClient
        self.sessionRepository = sessionRepository
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
        
        analysisState = .loading
        analysisProgress = 0
        
        // Simulate progress updates
        let progressTask = Task {
            for step in 1...9 {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { break }
                analysisProgress = Double(step) / 10.0
            }
        }
        
        defer {
            progressTask.cancel()
            analysisProgress = 1.0
        }
        
        do {
            let request = AnalysisRequest(inputText: inputText)
            
            let response = try await aiClient.analyze(request)
            analysisResult = response.feedback
            
            // Save or update session
            let savedSession = try saveSession(with: response.feedback)
            analysisState = .success(savedSession)
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
    
    private func saveSession(with feedback: StructuredFeedback?) throws -> Session {
        if let existingSession = session {
            // Update existing session
            existingSession.inputText = inputText
            existingSession.structuredFeedback = feedback
            existingSession.version += 1
            
            // Save attachments
            for attachment in attachments {
                if !existingSession.attachments.contains(where: { $0.id == attachment.id }) {
                    try sessionRepository.saveAttachment(attachment, to: existingSession)
                }
            }
            
            try sessionRepository.update(existingSession, title: nil, tags: nil)
            return existingSession
        } else {
            // Create new session
            let newSession = Session(
                title: "",
                role: nil,
                inputText: inputText,
                structuredFeedback: feedback,
                rubric: .general,
                tags: [],
                audioFileURL: audioURL,
                attachments: attachments
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
}
