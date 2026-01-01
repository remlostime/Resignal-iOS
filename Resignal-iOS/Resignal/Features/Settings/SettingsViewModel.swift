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
final class SettingsViewModel {
    
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
    
    var showClearConfirmation: Bool = false
    var showClearedMessage: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    
    // MARK: - Computed Properties
    
    var appVersion: String {
        if let service = settingsService as? SettingsService {
            return service.appVersion
        }
        return "1.0"
    }
    
    var isAPIConfigured: Bool {
        !apiKey.isEmpty && !apiBaseURL.isEmpty
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
    }
    
    // MARK: - Public Methods
    
    /// Clears all sessions
    func clearAllSessions() {
        do {
            try sessionRepository.deleteAll()
            showClearedMessage = true
            
            // Auto-dismiss after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                showClearedMessage = false
            }
        } catch {
            errorMessage = "Failed to clear sessions: \(error.localizedDescription)"
            showError = true
            debugLog("Error clearing sessions: \(error)")
        }
    }
    
    /// Confirms clear all action
    func confirmClearAll() {
        showClearConfirmation = true
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SettingsViewModel] \(message)")
        #endif
    }
}

