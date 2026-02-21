//
//  PaywallView.swift
//  Resignal
//
//  Paywall screen for upgrading to Pro subscription.
//  Compact Notion-inspired design — fits on one screen without scrolling.
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
            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.lg)

                // Feature list
                featureListSection

                Spacer()

                // Pricing cards (horizontal)
                pricingSection

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.lg)

                // Subscribe button + trial info
                actionSection

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.md)

                // Compact footer links
                footerLinks

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.sm)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
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
        VStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.primary)
                .padding(.bottom, AppTheme.Spacing.xxs)

            Text("Unlock Pro")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Perform better in interviews")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeatureBullet(icon: "infinity", title: "Unlimited sessions", subtitle: "No monthly session limits")
            Divider().padding(.leading, 44)
            FeatureBullet(icon: "sparkles", title: "AI answer rewriting", subtitle: "Get improved versions of your answers")
            Divider().padding(.leading, 44)
            FeatureBullet(icon: "star.circle", title: "Priority support", subtitle: "Get help when you need it")
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    // MARK: - Pricing (Horizontal)

    private var pricingSection: some View {
        Group {
            let products = container.subscriptionService.products

            if products.isEmpty {
                Text("Loading plans...")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
            } else {
                HStack(spacing: AppTheme.Spacing.sm) {
                    // Sort so monthly comes first (best value)
                    ForEach(sortedProducts(products), id: \.id) { product in
                        PricingCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id
                        ) {
                            withAnimation(AppTheme.Animation.fast) {
                                selectedProduct = product
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            // Free trial hint
            Text("7-day free trial included")
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // Subscribe button with dynamic price
            PrimaryButton(
                subscribeButtonTitle,
                isLoading: isPurchasing,
                isDisabled: selectedProduct == nil
            ) {
                Task {
                    await purchaseSelected()
                }
            }
        }
    }

    // MARK: - Footer Links

    private var footerLinks: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .disabled(isPurchasing)

            HStack(spacing: AppTheme.Spacing.md) {
                Link("Terms of service",
                     destination: container.settingsService.apiEnvironment.termsOfServiceURL)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)

                Link("Privacy policy",
                     destination: container.settingsService.apiEnvironment.privacyPolicyURL)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Helpers

    private var subscribeButtonTitle: String {
        guard let product = selectedProduct else {
            return "Subscribe"
        }
        let period = product.id == SubscriptionProductID.monthly ? "month" : "week"
        return "Subscribe for \(product.displayPrice) / \(period)"
    }

    private func sortedProducts(_ products: [Product]) -> [Product] {
        // Monthly first, then weekly
        products.sorted { lhs, _ in lhs.id == SubscriptionProductID.monthly }
    }

    private func selectDefaultProduct() {
        let products = container.subscriptionService.products
        // Default to monthly (best value)
        selectedProduct = products.first(where: { $0.id == SubscriptionProductID.monthly })
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

/// A feature bullet row — icon + title + subtitle
private struct FeatureBullet: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxxs) {
                Text(title)
                    .font(AppTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Pricing Card (Notion-style vertical)

/// Vertical pricing card for side-by-side plan comparison
private struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                // Price
                Text(product.displayPrice)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Period
                Text("per \(periodLabel)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                // Billing note
                Text("paid \(billingNote)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .offset(x: -AppTheme.Spacing.xs, y: AppTheme.Spacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var periodLabel: String {
        product.id == SubscriptionProductID.monthly ? "month" : "week"
    }

    private var billingNote: String {
        product.id == SubscriptionProductID.monthly ? "monthly" : "weekly"
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(DependencyContainer.preview())
}
