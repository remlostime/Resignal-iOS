//
//  AppReviewService.swift
//  Resignal
//
//  Manages app review prompt gating, lifetime usage tracking, and cooldown logic.
//  Persists all state in UserDefaults so it survives app restarts.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppReviewService: AppReviewServiceProtocol {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let lifetimeSessionCount = "appReview.lifetimeSessionCount"
        static let lifetimeAskMessageCount = "appReview.lifetimeAskMessageCount"
        static let promptShownCount = "appReview.promptShownCount"
        static let lastPromptDate = "appReview.lastPromptDate"
        static let reviewSubmitted = "appReview.reviewSubmitted"
        static let lastDismissedDate = "appReview.lastDismissedDate"
        static let systemReviewTriggered = "appReview.systemReviewTriggered"
    }
    
    // MARK: - Dependencies
    
    private let defaults: UserDefaults
    
    // MARK: - Stored Properties
    
    private(set) var lifetimeSessionCount: Int
    private(set) var lifetimeAskMessageCount: Int
    private var promptShownCount: Int
    private var lastPromptDate: Date?
    private var reviewSubmitted: Bool
    private var lastDismissedDate: Date?
    private var systemReviewTriggered: Bool
    
    var hasPendingPrompt: Bool = false
    
    // MARK: - Initialization
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lifetimeSessionCount = defaults.integer(forKey: Keys.lifetimeSessionCount)
        self.lifetimeAskMessageCount = defaults.integer(forKey: Keys.lifetimeAskMessageCount)
        self.promptShownCount = defaults.integer(forKey: Keys.promptShownCount)
        self.lastPromptDate = defaults.object(forKey: Keys.lastPromptDate) as? Date
        self.reviewSubmitted = defaults.bool(forKey: Keys.reviewSubmitted)
        self.lastDismissedDate = defaults.object(forKey: Keys.lastDismissedDate) as? Date
        self.systemReviewTriggered = defaults.bool(forKey: Keys.systemReviewTriggered)
    }
    
    // MARK: - Gating Logic
    
    func shouldPromptReview() -> Bool {
        if reviewSubmitted { return false }
        if promptShownCount >= AppReviewConstants.maxLifetimePrompts { return false }
        
        if let lastDismissed = lastDismissedDate {
            let cooldownEnd = Calendar.current.date(
                byAdding: .day,
                value: AppReviewConstants.dismissCooldownDays,
                to: lastDismissed
            ) ?? lastDismissed
            if Date() < cooldownEnd { return false }
        }
        
        if let lastPrompt = lastPromptDate {
            let cooldownEnd = Calendar.current.date(
                byAdding: .day,
                value: AppReviewConstants.dismissCooldownDays,
                to: lastPrompt
            ) ?? lastPrompt
            if Date() < cooldownEnd { return false }
        }
        
        return true
    }
    
    // MARK: - Recording Events
    
    func recordSessionCompleted() {
        lifetimeSessionCount += 1
        defaults.set(lifetimeSessionCount, forKey: Keys.lifetimeSessionCount)
        debugLog("Lifetime session count: \(lifetimeSessionCount)")
    }
    
    func recordAskMessageSent() {
        lifetimeAskMessageCount += 1
        defaults.set(lifetimeAskMessageCount, forKey: Keys.lifetimeAskMessageCount)
        debugLog("Lifetime ask message count: \(lifetimeAskMessageCount)")
    }
    
    func recordPromptShown() {
        promptShownCount += 1
        lastPromptDate = Date()
        defaults.set(promptShownCount, forKey: Keys.promptShownCount)
        defaults.set(lastPromptDate, forKey: Keys.lastPromptDate)
        debugLog("Prompt shown count: \(promptShownCount)")
    }
    
    func recordReviewSubmitted() {
        reviewSubmitted = true
        systemReviewTriggered = true
        defaults.set(true, forKey: Keys.reviewSubmitted)
        defaults.set(true, forKey: Keys.systemReviewTriggered)
        debugLog("Review submitted, will not prompt again")
    }
    
    func recordDismissed() {
        lastDismissedDate = Date()
        defaults.set(lastDismissedDate, forKey: Keys.lastDismissedDate)
        debugLog("Prompt dismissed, cooldown started")
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AppReviewService] \(message)")
        #endif
    }
}
