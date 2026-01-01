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
final class HomeViewModel: HomeViewModelProtocol {
    
    // MARK: - Properties
    
    private let sessionRepository: SessionRepositoryProtocol
    
    var sessions: [Session] = []
    var state: ViewState<[Session]> = .idle
    var searchText: String = ""
    var showDeleteConfirmation: Bool = false
    var sessionToDelete: Session?
    var sessionToRename: Session?
    var renameText: String = ""
    
    // MARK: - Computed Properties
    
    var filteredSessions: [Session] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter { session in
            session.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (session.role?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // MARK: - Initialization
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    // MARK: - Public Methods
    
    /// Loads all sessions from the repository
    func loadSessions() {
        state = .loading
        
        do {
            sessions = try sessionRepository.fetchAll()
            state = .success(sessions)
        } catch {
            state = .error("Failed to load sessions: \(error.localizedDescription)")
            debugLog("Error loading sessions: \(error)")
        }
    }
    
    /// Deletes the specified session
    func deleteSession(_ session: Session) {
        do {
            try sessionRepository.delete(session)
            sessions.removeAll { $0.id == session.id }
            state = .success(sessions)
        } catch {
            state = .error("Failed to delete session: \(error.localizedDescription)")
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
            state = .error("Failed to rename session: \(error.localizedDescription)")
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
    
    /// Clears any error state
    func clearError() {
        if state.hasError {
            state = .success(sessions)
        }
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[HomeViewModel] \(message)")
        #endif
    }
}
