//
//  OnboardingView.swift
//  Resignal
//
//  Minimal single-screen onboarding that sets psychological framing
//  for first-time users. Appears only on first launch.
//

import SwiftUI

/// A minimal onboarding screen with fade-in animation
struct OnboardingView: View {
    
    // MARK: - Properties
    
    let viewModel: OnboardingViewModel
    
    @State private var showContent = false
    @State private var showButton = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            Spacer()
            
            // Title + Subtitle
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Practice. Reflect. Improve.")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("Record or paste your mock interviews.")
                    Text("Get structured feedback.")
                    Text("Perform better.")
                }
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 12)
            
            Spacer()
            
            // Buttons
            VStack(spacing: AppTheme.Spacing.md) {
                Button {
                    viewModel.completeOnboarding()
                } label: {
                    Text("Start")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                }
                
                Button {
                    viewModel.completeOnboarding()
                } label: {
                    Text("Already know how it works? Skip")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xxl)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .onAppear {
            withAnimation(AppTheme.Animation.slow) {
                showContent = true
            }
            withAnimation(AppTheme.Animation.slow.delay(0.2)) {
                showButton = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(
            settingsService: SettingsService()
        )
    )
}
