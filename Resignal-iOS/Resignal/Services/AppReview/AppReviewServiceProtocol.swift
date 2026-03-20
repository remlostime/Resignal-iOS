//
//  AppReviewServiceProtocol.swift
//  Resignal
//
//  Protocol defining the app review and feedback flow gating logic.
//

import Foundation

// MARK: - Constants

enum AppReviewConstants {
    static let maxLifetimePrompts = 3
    static let minSessionsForFirstPrompt = 1
    static let sessionCountForAutoPrompt = 2
    static let askCountForPrompt = 2
    static let dismissCooldownDays = 14
    static let feedbackReadDelay: TimeInterval = 3.0
}

// MARK: - App Review Service Protocol

@MainActor
protocol AppReviewServiceProtocol: AnyObject, Sendable {
    
    /// Whether the review prompt should be shown based on all gating rules.
    func shouldPromptReview() -> Bool
    
    /// Whether a review prompt is waiting to be shown (set by triggers, consumed by UI).
    var hasPendingPrompt: Bool { get set }
    
    // MARK: - Lifetime Counters
    
    var lifetimeSessionCount: Int { get }
    var lifetimeAskMessageCount: Int { get }
    
    // MARK: - Recording Events
    
    /// Increments the lifetime session counter. Called after every successful analysis.
    func recordSessionCompleted()
    
    /// Increments the lifetime Ask message counter. Called after every successful Ask send.
    func recordAskMessageSent()
    
    /// Records that the sentiment prompt was shown to the user.
    func recordPromptShown()
    
    /// Records that the user tapped "Leave a review" and the system dialog was triggered.
    func recordReviewSubmitted()
    
    /// Records that the user dismissed the prompt or submitted feedback (not a review).
    func recordDismissed()
}
