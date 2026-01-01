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
final class EditorViewModel {
    
    // MARK: - Properties
    
    private let aiClient: any AIClient
    private let sessionRepository: SessionRepositoryProtocol
    
    // Session data
    var session: Session?
    var role: String = ""
    var rubric: Rubric = .softwareEngineering
    var tags: [String] = []
    var inputText: String = ""
    
    // UI state
    var isAnalyzing: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var analysisProgress: Double = 0
    
    // Analysis result
    var analysisResult: String?
    
    // Minimum character count for analysis
    private let minimumCharacterCount = 20
    
    // MARK: - Computed Properties
    
    var canAnalyze: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumCharacterCount
    }
    
    var characterCountMessage: String {
        let count = inputText.trimmingCharacters(in: .whitespacesAndNewlines).count
        if count < minimumCharacterCount {
            return "\(minimumCharacterCount - count) more characters needed"
        }
        return "\(count) characters"
    }
    
    var isEditing: Bool {
        session != nil
    }
    
    // MARK: - Initialization
    
    init(
        aiClient: any AIClient,
        sessionRepository: SessionRepositoryProtocol,
        session: Session? = nil
    ) {
        self.aiClient = aiClient
        self.sessionRepository = sessionRepository
        self.session = session
        
        // Pre-populate from existing session
        if let session = session {
            self.role = session.role ?? ""
            self.rubric = session.rubricType
            self.tags = session.tags
            self.inputText = session.inputText
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts the AI analysis
    func analyze() async -> Session? {
        guard canAnalyze else { return nil }
        
        isAnalyzing = true
        errorMessage = nil
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
            isAnalyzing = false
            analysisProgress = 1.0
        }
        
        do {
            let request = AnalysisRequest(
                inputText: inputText,
                role: role.isEmpty ? nil : role,
                rubric: rubric
            )
            
            let response = try await aiClient.analyze(request)
            analysisResult = response.feedback
            
            // Save or update session
            let savedSession = try saveSession(with: response.feedback)
            return savedSession
            
        } catch let error as AIClientError {
            errorMessage = error.localizedDescription
            showError = true
            debugLog("Analysis error: \(error)")
            return nil
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            showError = true
            debugLog("Unexpected error: \(error)")
            return nil
        }
    }
    
    /// Cancels the ongoing analysis
    func cancelAnalysis() {
        aiClient.cancel()
        isAnalyzing = false
        analysisProgress = 0
    }
    
    /// Saves the session without analysis (draft)
    func saveDraft() -> Session? {
        do {
            return try saveSession(with: "")
        } catch {
            errorMessage = "Failed to save draft: \(error.localizedDescription)"
            showError = true
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func saveSession(with feedback: String) throws -> Session {
        if let existingSession = session {
            // Update existing session
            existingSession.inputText = inputText
            existingSession.outputFeedback = feedback
            existingSession.role = role.isEmpty ? nil : role
            existingSession.rubricType = rubric
            existingSession.tags = tags
            existingSession.version += 1
            
            try sessionRepository.update(existingSession, title: nil, tags: tags)
            return existingSession
        } else {
            // Create new session
            let newSession = Session(
                title: "",
                role: role.isEmpty ? nil : role,
                inputText: inputText,
                outputFeedback: feedback,
                rubric: rubric,
                tags: tags
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

