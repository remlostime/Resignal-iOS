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
    var interviews: [InterviewDTO] { get }
    var filteredInterviews: [InterviewDTO] { get }
    var searchText: String { get set }
    var state: ViewState<[InterviewDTO]> { get }
    var showDeleteConfirmation: Bool { get set }
    var interviewToDelete: InterviewDTO? { get set }
    var renameText: String { get set }
    
    func loadInterviews() async
    func confirmDelete(_ interview: InterviewDTO)
    func executePendingDelete()
    func cancelDelete()
    func findLocalSession(for interview: InterviewDTO) -> Session?
    func clearError()
}

// MARK: - EditorViewModelProtocol

/// Protocol defining the EditorViewModel interface
@MainActor
protocol EditorViewModelProtocol: AnyObject, Observable {
    var session: Session? { get }
    var inputText: String { get set }
    var attachments: [SessionAttachment] { get set }
    var analysisState: ViewState<Session> { get }
    var analysisProgress: Double { get }
    var analysisResult: StructuredFeedback? { get }
    var canAnalyze: Bool { get }
    var characterCountMessage: String { get }
    var isEditing: Bool { get }
    var isAnalyzing: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    var showAttachmentPicker: Bool { get set }
    
    func analyze() async -> Session?
    func cancelAnalysis()
    func saveDraft() -> Session?
    func clearError()
    func addAttachment(_ attachment: SessionAttachment)
    func removeAttachment(_ attachment: SessionAttachment)
    func toggleAttachmentPicker()
}

// MARK: - ResultViewModelProtocol

/// Protocol defining the ResultViewModel interface
@MainActor
protocol ResultViewModelProtocol: AnyObject, Observable {
    var session: Session { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    
    func clearError()
}

// MARK: - OnboardingViewModelProtocol

/// Protocol defining the OnboardingViewModel interface
@MainActor
protocol OnboardingViewModelProtocol: AnyObject, Observable {
    func completeOnboarding()
}

