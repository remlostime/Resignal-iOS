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
    
    /// Marks onboarding as seen so the user proceeds to the main app
    func completeOnboarding() {
        settingsService.hasSeenOnboarding = true
    }
}
