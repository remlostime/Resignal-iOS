//
//  SettingsViewModel.swift
//  Resignal
//
//  ViewModel for the user-facing Settings screen.
//  Handles data deletion (both server-side and local).
//

import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    
    // MARK: - Dependencies
    
    private let userClient: any UserClient
    private let sessionRepository: SessionRepositoryProtocol
    private let settingsService: SettingsServiceProtocol
    
    // MARK: - State
    
    var showDeleteConfirmation = false
    var isDeleting = false
    var showError = false
    var errorMessage = ""
    var showDeleteSuccess = false
    
    var appVersion: String { settingsService.appVersion }
    
    // MARK: - Initialization
    
    init(
        userClient: any UserClient,
        sessionRepository: SessionRepositoryProtocol,
        settingsService: SettingsServiceProtocol
    ) {
        self.userClient = userClient
        self.sessionRepository = sessionRepository
        self.settingsService = settingsService
    }
    
    // MARK: - Actions
    
    func confirmDeleteAllData() {
        showDeleteConfirmation = true
    }
    
    /// Deletes all user data from the server and clears local sessions.
    func deleteAllData() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            try await userClient.deleteAllData()
            try sessionRepository.deleteAll()
            showDeleteSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
