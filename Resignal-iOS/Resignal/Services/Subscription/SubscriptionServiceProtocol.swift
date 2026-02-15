//
//  SubscriptionServiceProtocol.swift
//  Resignal
//
//  Protocol defining the subscription service interface using StoreKit 2.
//

import Foundation
import StoreKit

// MARK: - Purchase State

/// Represents the current state of a purchase operation
enum PurchaseState: Equatable, Sendable {
    case idle
    case purchasing
    case purchased
    case restored
    case failed(String)
    case pending
}

// MARK: - Subscription Product Identifiers

/// Product identifiers matching App Store Connect / StoreKit configuration
enum SubscriptionProductID {
    static let weekly = "com.resignal.pro.weekly"
    static let monthly = "com.resignal.pro.monthly"
    
    static var all: Set<String> {
        [weekly, monthly]
    }
}

// MARK: - Subscription Service Protocol

/// Protocol defining the subscription service interface.
/// Uses the existing `Plan` enum (`.free`, `.pro`) for extensibility.
@MainActor
protocol SubscriptionServiceProtocol: AnyObject, Sendable {
    /// The user's current subscription plan
    var currentPlan: Plan { get }
    
    /// Available subscription products loaded from the App Store
    var products: [Product] { get }
    
    /// Current state of any purchase operation
    var purchaseState: PurchaseState { get }
    
    /// Loads available subscription products from the App Store
    func loadProducts() async
    
    /// Purchases the given product
    /// - Parameter product: The StoreKit product to purchase
    func purchase(_ product: Product) async throws
    
    /// Restores previous purchases by syncing with the App Store
    func restorePurchases() async
    
    /// Listens for transaction updates (renewals, revocations, etc.)
    /// Should be called at app startup and kept alive for the app's lifetime
    func listenForTransactions() async
}
