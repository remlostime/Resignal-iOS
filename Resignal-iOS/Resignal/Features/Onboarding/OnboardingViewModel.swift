//
//  OnboardingViewModel.swift
//  Resignal
//
//  ViewModel for the onboarding flow. Marks onboarding as complete
//  when the user taps Start or Skip.
//

import Foundation

/// ViewModel that handles onboarding completion
@MainActor
@Observable
final class OnboardingViewModel: OnboardingViewModelProtocol {
    
    // MARK: - Dependencies
    
    private let settingsService: SettingsServiceProtocol
    
    // MARK: - Initialization
    
    init(settingsService: SettingsServiceProtocol) {
        self.settingsService = settingsService
    }
    
    // MARK: - Actions
    
    /// Marks onboarding as seen and records terms acceptance so the user proceeds to the main app.
    func completeOnboarding() {
        settingsService.hasAcceptedTerms = true
        settingsService.hasSeenOnboarding = true
    }
}
