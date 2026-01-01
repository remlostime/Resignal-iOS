//
//  HomeViewModel.swift
//  Resignal
//
//  ViewModel for the Home/Session List screen.
//

import Foundation
import SwiftUI

/// ViewModel managing the home screen state and logic
@MainActor
@Observable
final class HomeViewModel {
    
    // MARK: - Properties
    
    private let sessionRepository: SessionRepositoryProtocol
    
    var sessions: [Session] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showDeleteConfirmation: Bool = false
    var sessionToDelete: Session?
    var sessionToRename: Session?
    var renameText: String = ""
    
    // MARK: - Initialization
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    // MARK: - Public Methods
    
    /// Loads all sessions from the repository
    func loadSessions() {
        isLoading = true
        errorMessage = nil
        
        do {
            sessions = try sessionRepository.fetchAll()
            isLoading = false
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            isLoading = false
            debugLog("Error loading sessions: \(error)")
        }
    }
    
    /// Deletes the specified session
    func deleteSession(_ session: Session) {
        do {
            try sessionRepository.delete(session)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
            debugLog("Error deleting session: \(error)")
        }
    }
    
    /// Prepares for session deletion (shows confirmation)
    func confirmDelete(_ session: Session) {
        sessionToDelete = session
        showDeleteConfirmation = true
    }
    
    /// Confirms and executes pending deletion
    func executePendingDelete() {
        guard let session = sessionToDelete else { return }
        deleteSession(session)
        sessionToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Cancels pending deletion
    func cancelDelete() {
        sessionToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Prepares for session rename
    func startRename(_ session: Session) {
        sessionToRename = session
        renameText = session.title
    }
    
    /// Executes rename with current text
    func executeRename() {
        guard let session = sessionToRename else { return }
        
        do {
            try sessionRepository.update(session, title: renameText, tags: nil)
            loadSessions() // Refresh list
        } catch {
            errorMessage = "Failed to rename session: \(error.localizedDescription)"
            debugLog("Error renaming session: \(error)")
        }
        
        sessionToRename = nil
        renameText = ""
    }
    
    /// Cancels rename operation
    func cancelRename() {
        sessionToRename = nil
        renameText = ""
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[HomeViewModel] \(message)")
        #endif
    }
}

