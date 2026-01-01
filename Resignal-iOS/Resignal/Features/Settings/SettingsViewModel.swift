//
//  SettingsViewModel.swift
//  Resignal
//
//  ViewModel for the settings screen.
//

import Foundation
import SwiftUI

/// ViewModel managing the settings screen state
@MainActor
@Observable
final class SettingsViewModel: SettingsViewModelProtocol {
    
    // MARK: - Properties
    
    private let settingsService: SettingsServiceProtocol
    private let sessionRepository: SessionRepositoryProtocol
    
    var useMockAI: Bool {
        didSet {
            settingsService.useMockAI = useMockAI
        }
    }
    
    var apiBaseURL: String {
        didSet {
            settingsService.apiBaseURL = apiBaseURL
        }
    }
    
    var apiKey: String {
        didSet {
            settingsService.apiKey = apiKey
        }
    }
    
    var aiModel: String {
        didSet {
            settingsService.aiModel = aiModel
        }
    }
    
    var showClearConfirmation: Bool = false
    var showClearedMessage: Bool = false
    var clearState: VoidState = .idle
    
    // MARK: - Computed Properties
    
    var appVersion: String {
        settingsService.appVersion
    }
    
    var isAPIConfigured: Bool {
        !apiKey.isEmpty && !apiBaseURL.isEmpty
    }
    
    var errorMessage: String? {
        clearState.error
    }
    
    var showError: Bool {
        get { clearState.hasError }
        set { if !newValue { clearError() } }
    }
    
    // MARK: - Initialization
    
    init(
        settingsService: SettingsServiceProtocol,
        sessionRepository: SessionRepositoryProtocol
    ) {
        self.settingsService = settingsService
        self.sessionRepository = sessionRepository
        self.useMockAI = settingsService.useMockAI
        self.apiBaseURL = settingsService.apiBaseURL
        self.apiKey = settingsService.apiKey
        self.aiModel = settingsService.aiModel
    }
    
    // MARK: - Public Methods
    
    /// Clears all sessions
    func clearAllSessions() {
        do {
            try sessionRepository.deleteAll()
            clearState = .success(.empty)
            showClearedMessage = true
            
            // Auto-dismiss after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                showClearedMessage = false
            }
        } catch {
            clearState = .error("Failed to clear sessions: \(error.localizedDescription)")
            debugLog("Error clearing sessions: \(error)")
        }
    }
    
    /// Confirms clear all action
    func confirmClearAll() {
        showClearConfirmation = true
    }
    
    /// Clears any error state
    func clearError() {
        if clearState.hasError {
            clearState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SettingsViewModel] \(message)")
        #endif
    }
}
