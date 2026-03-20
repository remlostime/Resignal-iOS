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
    
    var interviews: [InterviewDTO] = []
    var searchText: String = ""
    var state: ViewState<[InterviewDTO]> = .idle
    var showDeleteConfirmation: Bool = false
    var interviewToDelete: InterviewDTO?
    var renameText: String = ""
    
    // MARK: - Initialization
    
    init(interviewClient: any InterviewClient) {
        self.interviewClient = interviewClient
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
    
    /// Prepares for interview deletion (shows confirmation)
    func confirmDelete(_ interview: InterviewDTO) {
        interviewToDelete = interview
        showDeleteConfirmation = true
    }
    
    /// Confirms and executes pending deletion against the server API
    func executePendingDelete() async {
        guard let interview = interviewToDelete else { return }
        
        interviews.removeAll { $0.id == interview.id }
        state = .success(interviews)
        interviewToDelete = nil
        showDeleteConfirmation = false
        
        do {
            try await interviewClient.deleteInterview(id: interview.id)
        } catch {
            interviews.append(interview)
            interviews.sort { $0.createdAt > $1.createdAt }
            state = .error("Failed to delete interview: \(error.localizedDescription)")
            debugLog("Error deleting interview: \(error)")
        }
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
