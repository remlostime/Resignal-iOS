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
    
    private let interviewClient: any InterviewClient
    private let sessionRepository: SessionRepositoryProtocol
    
    var interviews: [InterviewDTO] = []
    var searchText: String = ""
    var state: ViewState<[InterviewDTO]> = .idle
    var showDeleteConfirmation: Bool = false
    var interviewToDelete: InterviewDTO?
    var renameText: String = ""
    
    // MARK: - Initialization
    
    init(
        interviewClient: any InterviewClient,
        sessionRepository: SessionRepositoryProtocol
    ) {
        self.interviewClient = interviewClient
        self.sessionRepository = sessionRepository
    }
    
    // MARK: - Computed Properties
    
    var filteredInterviews: [InterviewDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return interviews }
        return interviews.filter { interview in
            (interview.title?.lowercased().contains(query) ?? false)
            || (interview.summary?.lowercased().contains(query) ?? false)
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches interviews from the backend API
    func loadInterviews() async {
        if interviews.isEmpty {
            state = .loading
        }
        
        do {
            let response = try await interviewClient.fetchInterviews(page: 1, pageSize: 20)
            interviews = response.interviews
            state = .success(interviews)
        } catch {
            state = .error("Failed to load interviews: \(error.localizedDescription)")
            debugLog("Error loading interviews: \(error)")
        }
    }
    
    /// Looks up the local SwiftData Session that corresponds to an API interview
    func findLocalSession(for interview: InterviewDTO) -> Session? {
        let allSessions = (try? sessionRepository.fetchAll()) ?? []
        return allSessions.first { $0.interviewId == interview.id }
    }
    
    /// Prepares for interview deletion (shows confirmation)
    func confirmDelete(_ interview: InterviewDTO) {
        interviewToDelete = interview
        showDeleteConfirmation = true
    }
    
    /// Confirms and executes pending deletion
    func executePendingDelete() {
        guard let interview = interviewToDelete else { return }
        
        if let session = findLocalSession(for: interview) {
            do {
                try sessionRepository.delete(session)
            } catch {
                state = .error("Failed to delete session: \(error.localizedDescription)")
                debugLog("Error deleting session: \(error)")
            }
        }
        
        interviews.removeAll { $0.id == interview.id }
        state = .success(interviews)
        interviewToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Cancels pending deletion
    func cancelDelete() {
        interviewToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Clears any error state
    func clearError() {
        if state.hasError {
            state = .success(interviews)
        }
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[HomeViewModel] \(message)")
        #endif
    }
}
