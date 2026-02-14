//
//  PaywallView.swift
//  Resignal
//
//  Paywall screen for upgrading to Pro subscription.
//  Minimalist black & white design with monthly/yearly options.
//

import SwiftUI
import StoreKit

/// Paywall view presenting Pro subscription options
struct PaywallView: View {
    
    // MARK: - Properties
    
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var purchaseCompleted = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Feature list
                    featureListSection
                    
                    // Pricing cards
                    pricingSection
                    
                    // Free trial badge
                    freeTrialBadge
                    
                    // Action buttons
                    actionSection
                    
                    // Terms footer
                    termsFooter
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .onAppear {
                selectDefaultProduct()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An error occurred. Please try again.")
            }
            .onChange(of: purchaseCompleted) { _, completed in
                if completed {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.primary)
            
            Text("Unlock Pro")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Perform better in interviews")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, AppTheme.Spacing.md)
    }
    
    // MARK: - Feature List
    
    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FeatureBullet(icon: "infinity", title: "Unlimited practice", description: "No monthly analysis limits")
            
            Divider()
                .background(AppTheme.Colors.divider)
            
            FeatureBullet(
                icon: "sparkles",
                title: "AI answer rewriting",
                description: "Get improved versions of your answers"
            )
            
            Divider()
                .background(AppTheme.Colors.divider)
            
            FeatureBullet(
                icon: "bubble.left.and.bubble.right",
                title: "Follow-up questions",
                description: "Ask AI about your performance"
            )
            
            Divider()
                .background(AppTheme.Colors.divider)
            
            FeatureBullet(
                icon: "square.and.arrow.up",
                title: "Export & save history",
                description: "Unlimited session history and sharing"
            )
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
    
    // MARK: - Pricing
    
    private var pricingSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            let products = container.subscriptionService.products
            
            if products.isEmpty {
                // Fallback when products haven't loaded
                Text("Loading plans...")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.lg)
            } else {
                ForEach(products, id: \.id) { product in
                    PricingCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isBestValue: product.id == SubscriptionProductID.yearly
                    ) {
                        withAnimation(AppTheme.Animation.fast) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Free Trial Badge
    
    private var freeTrialBadge: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "gift")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("7-day free trial included")
                .font(AppTheme.Typography.callout.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.primary, lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private var actionSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            PrimaryButton(
                "Continue",
                icon: "arrow.right",
                isLoading: isPurchasing,
                isDisabled: selectedProduct == nil
            ) {
                Task {
                    await purchaseSelected()
                }
            }
            
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
            }
            .disabled(isPurchasing)
        }
    }
    
    // MARK: - Terms Footer
    
    private var termsFooter: some View {
        // swiftlint:disable:next line_length
        Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    // MARK: - Actions
    
    private func selectDefaultProduct() {
        let products = container.subscriptionService.products
        // Default to yearly (best value)
        selectedProduct = products.first(where: { $0.id == SubscriptionProductID.yearly })
            ?? products.first
    }
    
    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await container.subscriptionService.purchase(product)
            
            if container.subscriptionService.purchaseState == .purchased {
                purchaseCompleted = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        await container.subscriptionService.restorePurchases()
        
        let state = container.subscriptionService.purchaseState
        if state == .restored {
            purchaseCompleted = true
        } else if case .failed(let message) = state {
            errorMessage = message
            showError = true
        }
    }
}

// MARK: - Feature Bullet

/// A single feature bullet point with icon and description
private struct FeatureBullet: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pricing Card

/// Card displaying a subscription product option
private struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(product.displayName)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if isBestValue {
                            Text("Best Value")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(product.displayPrice + " / " + periodLabel(for: product))
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.Colors.primary
                            : AppTheme.Colors.textTertiary
                    )
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func periodLabel(for product: Product) -> String {
        if product.id == SubscriptionProductID.yearly {
            return "year"
        } else {
            return "month"
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(DependencyContainer.preview())
}
