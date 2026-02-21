//
//  FeatureAccessService.swift
//  Resignal
//
//  Protocol and implementation for feature gating based on subscription plan.
//  Tracks monthly session creation usage for free-tier limits.
//

import Foundation
import Observation

// MARK: - Feedback Section

/// Represents the sections in the feedback result view
enum FeedbackSection: CaseIterable, Sendable {
    case summary
    case strengths
    case improvement
    case hiringSignal
    case keyObservations
}

// MARK: - Feature Access Constants

/// Constants for free-tier limitations
enum FeatureAccessConstants {
    static let maxFreeSessionCreations = 3
}

// MARK: - Feature Access Service Protocol

/// Protocol defining feature access and gating logic
@MainActor
protocol FeatureAccessServiceProtocol: AnyObject, Sendable {
    /// The effective subscription plan (accounts for mock overrides in DEBUG)
    var currentPlan: Plan { get }
    
    /// Convenience: whether the user has Pro access
    var isPro: Bool { get }
    
    /// Number of sessions created this calendar month
    var sessionCreationCountThisMonth: Int { get }
    
    /// Whether the user can create a new session (Pro or under free limit)
    var canCreateSession: Bool { get }
    
    /// Maximum session creations allowed per month for free tier
    var maxFreeSessionCreations: Int { get }
    
    /// Number of remaining free session creations this month
    var remainingFreeSessionCreations: Int { get }
    
    /// Records that the user created a new session (increments monthly count)
    func recordSessionCreation()
    
    #if DEBUG
    /// Overrides the session creation count for testing paywall gating
    func overrideSessionCreationCount(_ count: Int)
    #endif
}

// MARK: - Feature Access Service Implementation

/// Determines feature access based on subscription status and usage tracking.
/// Persists monthly usage count in UserDefaults with automatic calendar-month reset.
@MainActor
@Observable
final class FeatureAccessService: FeatureAccessServiceProtocol {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let sessionCreationCount = "featureAccess.analysisCountThisMonth"
        static let lastResetDate = "featureAccess.lastResetDate"
    }
    
    // MARK: - Dependencies
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let settingsService: SettingsServiceProtocol
    private let defaults: UserDefaults
    
    // MARK: - Stored Properties
    
    private(set) var sessionCreationCountThisMonth: Int
    private var lastResetDate: Date
    
    // MARK: - Computed Properties
    
    var currentPlan: Plan {
        #if DEBUG
        if settingsService.mockSubscriptionEnabled {
            return settingsService.mockPlan
        }
        #endif
        return subscriptionService.currentPlan
    }
    
    var isPro: Bool {
        currentPlan == .pro
    }
    
    var canCreateSession: Bool {
        if isPro { return true }
        resetMonthlyCountIfNeeded()
        return sessionCreationCountThisMonth < FeatureAccessConstants.maxFreeSessionCreations
    }
    
    var maxFreeSessionCreations: Int {
        FeatureAccessConstants.maxFreeSessionCreations
    }
    
    var remainingFreeSessionCreations: Int {
        if isPro { return Int.max }
        resetMonthlyCountIfNeeded()
        return max(0, FeatureAccessConstants.maxFreeSessionCreations - sessionCreationCountThisMonth)
    }
    
    // MARK: - Initialization
    
    init(
        subscriptionService: SubscriptionServiceProtocol,
        settingsService: SettingsServiceProtocol,
        defaults: UserDefaults = .standard
    ) {
        self.subscriptionService = subscriptionService
        self.settingsService = settingsService
        self.defaults = defaults
        
        self.sessionCreationCountThisMonth = defaults.integer(forKey: Keys.sessionCreationCount)
        
        if let savedDate = defaults.object(forKey: Keys.lastResetDate) as? Date {
            self.lastResetDate = savedDate
        } else {
            self.lastResetDate = Date()
            defaults.set(Date(), forKey: Keys.lastResetDate)
        }
    }
    
    // MARK: - Public Methods
    
    func recordSessionCreation() {
        resetMonthlyCountIfNeeded()
        sessionCreationCountThisMonth += 1
        defaults.set(sessionCreationCountThisMonth, forKey: Keys.sessionCreationCount)
        debugLog("Session creation recorded. Count this month: \(sessionCreationCountThisMonth)")
    }
    
    #if DEBUG
    func overrideSessionCreationCount(_ count: Int) {
        sessionCreationCountThisMonth = max(0, count)
        defaults.set(sessionCreationCountThisMonth, forKey: Keys.sessionCreationCount)
        debugLog("Session creation count overridden to \(sessionCreationCountThisMonth)")
    }
    #endif
    
    // MARK: - Private Methods
    
    /// Resets the monthly session creation count if the calendar month has changed
    private func resetMonthlyCountIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        let lastMonth = calendar.component(.month, from: lastResetDate)
        let lastYear = calendar.component(.year, from: lastResetDate)
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        if currentYear != lastYear || currentMonth != lastMonth {
            sessionCreationCountThisMonth = 0
            lastResetDate = now
            defaults.set(0, forKey: Keys.sessionCreationCount)
            defaults.set(now, forKey: Keys.lastResetDate)
            debugLog("Monthly session creation count reset")
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[FeatureAccessService] \(message)")
        #endif
    }
}
