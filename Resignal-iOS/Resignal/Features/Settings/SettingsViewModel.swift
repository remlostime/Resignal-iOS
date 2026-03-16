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
    
    private let apiClient: APIClientProtocol
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
        apiClient: APIClientProtocol,
        settingsService: SettingsServiceProtocol
    ) {
        self.apiClient = apiClient
        self.settingsService = settingsService
    }
    
    // MARK: - Actions
    
    func confirmDeleteAllData() {
        showDeleteConfirmation = true
    }
    
    /// Deletes all user data from the server.
    /// User identity is derived from the JWT token.
    func deleteAllData() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            let _: EmptyResponse = try await apiClient.request(
                "/api/users/data",
                method: .delete
            )
            showDeleteSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

/// Placeholder for endpoints that return an empty or ignored body.
private struct EmptyResponse: Decodable {}
