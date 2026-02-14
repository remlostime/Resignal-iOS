//
//  MockSubscriptionService.swift
//  Resignal
//
//  Mock subscription service for DEBUG builds and SwiftUI previews.
//  Allows toggling subscription state without App Store configuration.
//

#if DEBUG

import Foundation
import StoreKit
import Observation

/// Mock subscription service for development and testing.
/// Provides manual control over subscription state without StoreKit.
@MainActor
@Observable
final class MockSubscriptionService: SubscriptionServiceProtocol {
    
    // MARK: - Properties
    
    var currentPlan: Plan = .free
    var products: [Product] = []
    var purchaseState: PurchaseState = .idle
    
    // MARK: - SubscriptionServiceProtocol
    
    func loadProducts() async {
        // Products cannot be constructed in tests;
        // the array remains empty in mock mode.
        debugLog("Mock: loadProducts called (no-op)")
    }
    
    func purchase(_ product: Product) async throws {
        purchaseState = .purchasing
        
        // Simulate a short delay
        try? await Task.sleep(for: .milliseconds(500))
        
        currentPlan = .pro
        purchaseState = .purchased
        debugLog("Mock: purchase simulated -> pro")
    }
    
    func restorePurchases() async {
        purchaseState = .purchasing
        
        // Simulate a short delay
        try? await Task.sleep(for: .milliseconds(300))
        
        if currentPlan == .pro {
            purchaseState = .restored
        } else {
            purchaseState = .idle
        }
        debugLog("Mock: restorePurchases -> \(currentPlan.rawValue)")
    }
    
    func listenForTransactions() async {
        // No-op in mock mode
        debugLog("Mock: listenForTransactions called (no-op)")
    }
    
    // MARK: - Mock Control
    
    /// Manually set the plan for testing
    func setMockPlan(_ plan: Plan) {
        currentPlan = plan
        debugLog("Mock: plan set to \(plan.rawValue)")
    }
    
    private func debugLog(_ message: String) {
        print("[MockSubscriptionService] \(message)")
    }
}

#endif
