//
//  ProBenefitsView.swift
//  Resignal
//
//  Benefits overview for Pro subscribers — no purchase UI.
//

import SwiftUI

/// Read-only view describing the benefits of the Pro plan
struct ProBenefitsView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.xl)

                headerSection

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.lg)

                featureListSection

                Spacer()

                footerSection

                Spacer()
                    .frame(maxHeight: AppTheme.Spacing.lg)
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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.primary)
                .padding(.bottom, AppTheme.Spacing.xxs)

            Text("You're on Pro")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Enjoy all the benefits of your plan")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeatureBullet(icon: "infinity", title: "Unlimited sessions", subtitle: "No monthly session limits")
            Divider().padding(.leading, 44)
            FeatureBullet(
                icon: "text.bubble",
                title: "Unlimited Ask follow-ups",
                subtitle: "Dig deeper with unlimited follow-up questions"
            )
            Divider().padding(.leading, 44)
            FeatureBullet(
                icon: "brain",
                title: "Better AI models analysis",
                subtitle: "Get more accurate and detailed feedback"
            )
            Divider().padding(.leading, 44)
            FeatureBullet(
                icon: "waveform",
                title: "Better audio recognition quality",
                subtitle: "Crystal-clear transcription of your responses"
            )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("Thank you for supporting Resignal!")
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(AppTheme.Colors.textTertiary)
    }
}

// MARK: - Preview

#Preview {
    ProBenefitsView()
        .environment(DependencyContainer.preview())
}
