//
//  FeatureAccessService.swift
//  Resignal
//
//  Protocol and implementation for feature gating based on subscription plan.
//  Tracks monthly usage for free-tier limits and determines section visibility.
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
    
    /// Sections available to free-tier users
    static let freeSections: Set<FeedbackSection> = [.summary, .strengths, .improvement]
    
    /// Sections exclusive to Pro-tier users
    static let proSections: Set<FeedbackSection> = [.hiringSignal, .keyObservations]
}

// MARK: - Feature Access Constants

/// Constants for free-tier limitations
enum FeatureAccessConstants {
    static let maxFreeAnalyses = 3
    static let maxFreeSessions = 5
}

// MARK: - Feature Access Service Protocol

/// Protocol defining feature access and gating logic
@MainActor
protocol FeatureAccessServiceProtocol: AnyObject, Sendable {
    /// The effective subscription plan (accounts for mock overrides in DEBUG)
    var currentPlan: Plan { get }
    
    /// Convenience: whether the user has Pro access
    var isPro: Bool { get }
    
    /// Number of analyses performed this calendar month
    var analysisCountThisMonth: Int { get }
    
    /// Whether the user can perform an analysis (Pro or under free limit)
    var canAnalyze: Bool { get }
    
    /// Maximum analyses allowed for free tier
    var maxFreeAnalyses: Int { get }
    
    /// Maximum saved sessions for free tier
    var maxFreeSessions: Int { get }
    
    /// Number of remaining free analyses this month
    var remainingFreeAnalyses: Int { get }
    
    /// Records that the user performed an analysis (increments monthly count)
    func recordAnalysis()
    
    /// Whether the given feedback section is viewable under the current plan
    func canViewFeedbackSection(_ section: FeedbackSection) -> Bool
    
    /// Whether the Ask (follow-up questions) tab is accessible
    func canUseAskTab() -> Bool
}

// MARK: - Feature Access Service Implementation

/// Determines feature access based on subscription status and usage tracking.
/// Persists monthly usage count in UserDefaults with automatic calendar-month reset.
@MainActor
@Observable
final class FeatureAccessService: FeatureAccessServiceProtocol {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let analysisCount = "featureAccess.analysisCountThisMonth"
        static let lastResetDate = "featureAccess.lastResetDate"
    }
    
    // MARK: - Dependencies
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let settingsService: SettingsServiceProtocol
    private let defaults: UserDefaults
    
    // MARK: - Stored Properties
    
    private(set) var analysisCountThisMonth: Int
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
    
    var canAnalyze: Bool {
        if isPro { return true }
        resetMonthlyCountIfNeeded()
        return analysisCountThisMonth < FeatureAccessConstants.maxFreeAnalyses
    }
    
    var maxFreeAnalyses: Int {
        FeatureAccessConstants.maxFreeAnalyses
    }
    
    var maxFreeSessions: Int {
        FeatureAccessConstants.maxFreeSessions
    }
    
    var remainingFreeAnalyses: Int {
        if isPro { return Int.max }
        resetMonthlyCountIfNeeded()
        return max(0, FeatureAccessConstants.maxFreeAnalyses - analysisCountThisMonth)
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
        
        // Load persisted values
        self.analysisCountThisMonth = defaults.integer(forKey: Keys.analysisCount)
        
        if let savedDate = defaults.object(forKey: Keys.lastResetDate) as? Date {
            self.lastResetDate = savedDate
        } else {
            self.lastResetDate = Date()
            defaults.set(Date(), forKey: Keys.lastResetDate)
        }
    }
    
    // MARK: - Public Methods
    
    func recordAnalysis() {
        resetMonthlyCountIfNeeded()
        analysisCountThisMonth += 1
        defaults.set(analysisCountThisMonth, forKey: Keys.analysisCount)
        debugLog("Analysis recorded. Count this month: \(analysisCountThisMonth)")
    }
    
    func canViewFeedbackSection(_ section: FeedbackSection) -> Bool {
        if isPro { return true }
        return FeedbackSection.freeSections.contains(section)
    }
    
    func canUseAskTab() -> Bool {
        isPro
    }
    
    // MARK: - Private Methods
    
    /// Resets the monthly analysis count if the calendar month has changed
    private func resetMonthlyCountIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        let lastMonth = calendar.component(.month, from: lastResetDate)
        let lastYear = calendar.component(.year, from: lastResetDate)
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        if currentYear != lastYear || currentMonth != lastMonth {
            analysisCountThisMonth = 0
            lastResetDate = now
            defaults.set(0, forKey: Keys.analysisCount)
            defaults.set(now, forKey: Keys.lastResetDate)
            debugLog("Monthly analysis count reset")
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[FeatureAccessService] \(message)")
        #endif
    }
}
