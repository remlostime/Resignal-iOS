//
//  SubscriptionService.swift
//  Resignal
//
//  StoreKit 2 implementation for managing subscriptions.
//  Handles product loading, purchasing, restoring, and transaction listening.
//

import Foundation
import StoreKit
import Observation

/// StoreKit 2 subscription service implementation
@MainActor
@Observable
final class SubscriptionService: SubscriptionServiceProtocol {
    
    // MARK: - Properties
    
    var currentPlan: Plan = .free
    var products: [Product] = []
    var purchaseState: PurchaseState = .idle
    
    /// Keeps the transaction listener task alive.
    /// `nonisolated(unsafe)` allows cancellation from `deinit` which runs nonisolated.
    private nonisolated(unsafe) var transactionListenerTask: Task<Void, Never>?
    
    private let billingClient: BillingClientProtocol
    
    // MARK: - Initialization
    
    init(billingClient: BillingClientProtocol) {
        self.billingClient = billingClient
        Task {
            await checkCurrentEntitlements()
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - SubscriptionServiceProtocol
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: SubscriptionProductID.all)
            
            // Sort: monthly first (best value), then weekly
            products = storeProducts.sorted { lhs, _ in
                lhs.id == SubscriptionProductID.monthly
            }
            
            debugLog("Loaded \(products.count) products")
        } catch {
            debugLog("Failed to load products: \(error.localizedDescription)")
            // Products array stays empty; UI should handle gracefully
        }
    }
    
    func purchase(_ product: Product) async throws {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerification(verification)
                
                await verifyTransactionWithBackend(verification.jwsRepresentation)
                await updatePlanFromTransaction(transaction)
                await transaction.finish()
                
                purchaseState = .purchased
                debugLog("Purchase successful: \(product.id)")
                
            case .userCancelled:
                purchaseState = .idle
                debugLog("Purchase cancelled by user")
                
            case .pending:
                purchaseState = .pending
                debugLog("Purchase pending (e.g. Ask to Buy)")
                
            @unknown default:
                purchaseState = .idle
                debugLog("Unknown purchase result")
            }
        } catch let error as SubscriptionError {
            purchaseState = .failed(error.localizedDescription)
            debugLog("Purchase failed: \(error.localizedDescription)")
            throw error
        } catch {
            purchaseState = .failed(error.localizedDescription)
            debugLog("Purchase failed: \(error.localizedDescription)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
    }
    
    func restorePurchases() async {
        purchaseState = .purchasing
        
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            
            if currentPlan == .pro {
                await verifyCurrentEntitlementWithBackend()
                purchaseState = .restored
                debugLog("Purchases restored successfully")
            } else {
                purchaseState = .idle
                debugLog("No active subscriptions found after restore")
            }
        } catch {
            purchaseState = .failed("Failed to restore purchases. Please try again.")
            debugLog("Restore failed: \(error.localizedDescription)")
        }
    }
    
    func listenForTransactions() async {
        // Cancel any existing listener
        transactionListenerTask?.cancel()
        
        transactionListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                
                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerification(result)
                    }
                    
                    let jwsRepresentation = result.jwsRepresentation
                    await MainActor.run {
                        Task {
                            await self.verifyTransactionWithBackend(jwsRepresentation)
                            await self.updatePlanFromTransaction(transaction)
                            await transaction.finish()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.debugLog("Transaction verification failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks current entitlements to determine the user's plan
    private func checkCurrentEntitlements() async {
        var foundProEntitlement = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerification(result)
                
                if SubscriptionProductID.all.contains(transaction.productID) {
                    // Verify the subscription hasn't been revoked
                    if transaction.revocationDate == nil {
                        foundProEntitlement = true
                    }
                }
            } catch {
                debugLog("Entitlement verification failed: \(error.localizedDescription)")
            }
        }
        
        currentPlan = foundProEntitlement ? .pro : .free
        debugLog("Current plan: \(currentPlan.rawValue)")
    }
    
    /// Updates the plan based on a verified transaction
    private func updatePlanFromTransaction(_ transaction: Transaction) async {
        if SubscriptionProductID.all.contains(transaction.productID) {
            if transaction.revocationDate == nil {
                currentPlan = .pro
            } else {
                // Subscription was revoked, recheck all entitlements
                await checkCurrentEntitlements()
            }
        }
    }
    
    /// Verifies a transaction result from StoreKit
    /// - Parameter result: The verification result from StoreKit
    /// - Returns: The verified transaction
    /// - Throws: SubscriptionError if verification fails
    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw SubscriptionError.verificationFailed(error.localizedDescription)
        case .verified(let safe):
            return safe
        }
    }
    
    /// Sends a StoreKit 2 JWS signed transaction to the backend for server-side verification.
    /// Failures are logged but do not block the purchase flow.
    private func verifyTransactionWithBackend(_ jwsRepresentation: String) async {
        do {
            let response = try await billingClient.verifyTransaction(signedTransaction: jwsRepresentation)
            if response.isPro {
                currentPlan = .pro
            }
            debugLog("Backend transaction verification: isPro=\(response.isPro)")
        } catch {
            debugLog("Backend transaction verification failed: \(error.localizedDescription)")
        }
    }
    
    /// Finds the active Pro entitlement and sends its JWS to the backend for verification.
    private func verifyCurrentEntitlementWithBackend() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerification(result)
                if SubscriptionProductID.all.contains(transaction.productID),
                   transaction.revocationDate == nil {
                    await verifyTransactionWithBackend(result.jwsRepresentation)
                    return
                }
            } catch {
                debugLog("Entitlement verification failed: \(error.localizedDescription)")
            }
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SubscriptionService] \(message)")
        #endif
    }
}

// MARK: - Subscription Error

/// Errors that can occur during subscription operations
enum SubscriptionError: LocalizedError {
    case purchaseFailed(String)
    case verificationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed(let reason):
            return "Purchase failed: \(reason)"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        }
    }
}
