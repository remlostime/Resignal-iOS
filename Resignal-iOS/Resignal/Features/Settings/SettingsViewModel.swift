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
    private let audioCacheService: AudioCacheService
    
    // MARK: - State
    
    var showDeleteConfirmation = false
    var isDeleting = false
    var showError = false
    var errorMessage = ""
    var showDeleteSuccess = false
    var cacheSizeBytes: Int64 = 0
    
    var appVersion: String { settingsService.appVersion }
    
    var cacheSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: cacheSizeBytes, countStyle: .file)
    }
    
    var hasCachedAudio: Bool { cacheSizeBytes > 0 }
    
    // MARK: - Initialization
    
    init(
        apiClient: APIClientProtocol,
        settingsService: SettingsServiceProtocol,
        audioCacheService: AudioCacheService = MockAudioCacheService()
    ) {
        self.apiClient = apiClient
        self.settingsService = settingsService
        self.audioCacheService = audioCacheService
    }
    
    func loadCacheSize() async {
        cacheSizeBytes = await audioCacheService.totalCacheSize()
    }
    
    func clearCache() {
        Task {
            await audioCacheService.evictAll()
            cacheSizeBytes = 0
        }
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
