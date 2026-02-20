//
//  OnboardingView.swift
//  Resignal
//
//  Minimal single-screen onboarding that sets psychological framing
//  for first-time users. Appears only on first launch.
//  Tapping "Start" implies acceptance of Privacy Policy & Terms of Service.
//

import SwiftUI

/// A minimal onboarding screen with fade-in animation
struct OnboardingView: View {
    
    // MARK: - Properties
    
    let viewModel: OnboardingViewModel
    
    @State private var showContent = false
    @State private var showButton = false
    @State private var safariURL: URL?
    
    private static let privacyPolicyURL = URL(string: "https://resignal.app/privacy")!
    private static let termsOfServiceURL = URL(string: "https://resignal.app/terms")!
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            Spacer()
            
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
            
            VStack(spacing: AppTheme.Spacing.sm) {
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
                
                consentText
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
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Subviews
    
    private var consentText: some View {
        HStack(spacing: 0) {
            Text("By tapping \"Start\", you agree to our ")
            
            Button {
                safariURL = Self.privacyPolicyURL
            } label: {
                Text("Privacy Policy")
                    .underline()
            }
            
            Text(" and ")
            
            Button {
                safariURL = Self.termsOfServiceURL
            } label: {
                Text("Terms of Service")
                    .underline()
            }
            
            Text(".")
        }
        .font(AppTheme.Typography.caption)
        .foregroundStyle(AppTheme.Colors.textTertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - URL + Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Preview

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(
            settingsService: SettingsService()
        )
    )
}
