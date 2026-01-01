//
//  ViewModelProtocols.swift
//  Resignal
//
//  Protocol definitions for ViewModels to enable mocking in tests and previews.
//

import Foundation
import SwiftUI

// MARK: - HomeViewModelProtocol

/// Protocol defining the HomeViewModel interface
@MainActor
protocol HomeViewModelProtocol: AnyObject, Observable {
    var sessions: [Session] { get }
    var state: ViewState<[Session]> { get }
    var searchText: String { get set }
    var filteredSessions: [Session] { get }
    var showDeleteConfirmation: Bool { get set }
    var sessionToDelete: Session? { get set }
    var sessionToRename: Session? { get set }
    var renameText: String { get set }
    
    func loadSessions()
    func deleteSession(_ session: Session)
    func confirmDelete(_ session: Session)
    func executePendingDelete()
    func cancelDelete()
    func startRename(_ session: Session)
    func executeRename()
    func cancelRename()
    func clearError()
}

// MARK: - EditorViewModelProtocol

/// Protocol defining the EditorViewModel interface
@MainActor
protocol EditorViewModelProtocol: AnyObject, Observable {
    var session: Session? { get }
    var role: String { get set }
    var rubric: Rubric { get set }
    var tags: [String] { get set }
    var inputText: String { get set }
    var analysisState: ViewState<Session> { get }
    var analysisProgress: Double { get }
    var analysisResult: String? { get }
    var canAnalyze: Bool { get }
    var characterCountMessage: String { get }
    var isEditing: Bool { get }
    var isAnalyzing: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    
    func analyze() async -> Session?
    func cancelAnalysis()
    func saveDraft() -> Session?
    func clearError()
}

// MARK: - ResultViewModelProtocol

/// Protocol defining the ResultViewModel interface
@MainActor
protocol ResultViewModelProtocol: AnyObject, Observable {
    var session: Session { get }
    var sections: FeedbackSections { get }
    var regenerateState: ViewState<FeedbackSections> { get }
    var showShareSheet: Bool { get set }
    var expandedSections: Set<FeedbackSection> { get set }
    var isRegenerating: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    var shareText: String { get }
    
    func isExpanded(_ section: FeedbackSection) -> Bool
    func toggleExpansion(_ section: FeedbackSection)
    func expansionBinding(for section: FeedbackSection) -> Binding<Bool>
    func regenerate() async
    func copyToClipboard()
    func clearError()
}

// MARK: - SettingsViewModelProtocol

/// Protocol defining the SettingsViewModel interface
@MainActor
protocol SettingsViewModelProtocol: AnyObject, Observable {
    var useMockAI: Bool { get set }
    var apiBaseURL: String { get set }
    var apiKey: String { get set }
    var aiModel: String { get set }
    var showClearConfirmation: Bool { get set }
    var showClearedMessage: Bool { get }
    var clearState: VoidState { get }
    var appVersion: String { get }
    var isAPIConfigured: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    
    func clearAllSessions()
    func confirmClearAll()
    func clearError()
}

