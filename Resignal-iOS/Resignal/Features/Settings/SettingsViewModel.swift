//
//  SettingsViewModel.swift
//  Resignal
//
//  ViewModel for the user-facing Settings screen.
//  Handles data deletion via the server API.
//

import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    
    // MARK: - Dependencies
    
    private let userClient: any UserClient
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
        settingsService: SettingsServiceProtocol
    ) {
        self.userClient = userClient
        self.settingsService = settingsService
    }
    
    // MARK: - Actions
    
    func confirmDeleteAllData() {
        showDeleteConfirmation = true
    }
    
    /// Deletes all user data from the server.
    func deleteAllData() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            try await userClient.deleteAllData()
            showDeleteSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
