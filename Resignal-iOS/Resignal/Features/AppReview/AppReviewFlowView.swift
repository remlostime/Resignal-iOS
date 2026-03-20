//
//  AppReviewFlowView.swift
//  Resignal
//
//  Multi-step sentiment check and review/feedback flow.
//  Presented as a sheet from InterviewDetailView.
//

import SwiftUI
import StoreKit

// MARK: - Flow Step

private enum AppReviewFlowStep {
    case sentimentCheck
    case positiveFollowUp
    case feedbackForm
}

// MARK: - App Review Flow View

struct AppReviewFlowView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    
    let appReviewService: AppReviewServiceProtocol
    
    @State private var step: AppReviewFlowStep = .sentimentCheck
    @State private var feedbackText: String = ""
    @State private var feedbackSubmitted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            
            switch step {
            case .sentimentCheck:
                sentimentCheckView
            case .positiveFollowUp:
                positiveFollowUpView
            case .feedbackForm:
                feedbackFormView
            }
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            appReviewService.recordPromptShown()
        }
    }
    
    // MARK: - Drag Indicator
    
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
            .fill(AppTheme.Colors.border)
            .frame(width: 36, height: 4)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.xs)
    }
    
    // MARK: - Step 1: Sentiment Check
    
    private var sentimentCheckView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "face.smiling")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("Has Resignal been helpful so far?")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                PrimaryButton("Yes", style: .filled) {
                    withAnimation(AppTheme.Animation.standard) {
                        step = .positiveFollowUp
                    }
                }
                
                PrimaryButton("Not really", style: .outlined) {
                    withAnimation(AppTheme.Animation.standard) {
                        step = .feedbackForm
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            dismissButton
            
            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
    }
    
    // MARK: - Step 2a: Positive Follow-Up
    
    private var positiveFollowUpView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("We're glad it's been helpful.")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                PrimaryButton("Leave a review", icon: "star", style: .filled) {
                    appReviewService.recordReviewSubmitted()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestReview()
                    }
                }
                
                PrimaryButton("Share feedback", icon: "bubble.left", style: .outlined) {
                    withAnimation(AppTheme.Animation.standard) {
                        step = .feedbackForm
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            dismissButton
            
            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
    }
    
    // MARK: - Step 2b / Feedback Form
    
    private var feedbackFormView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if feedbackSubmitted {
                feedbackConfirmationView
            } else {
                feedbackInputView
            }
        }
        .padding(AppTheme.Spacing.lg)
    }
    
    private var feedbackInputView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "envelope")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("We'd love to understand how we can improve.")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $feedbackText)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 180)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
                )
            
            PrimaryButton(
                "Submit",
                icon: "paperplane",
                isDisabled: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                style: .filled
            ) {
                submitFeedback()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            dismissButton
            
            Spacer()
        }
    }
    
    private var feedbackConfirmationView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.success)
            
            Text("Thank you for your feedback.")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("We'll use it to make Resignal better.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            PrimaryButton("Done", style: .filled) {
                dismiss()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            Spacer()
        }
    }
    
    // MARK: - Shared Components
    
    private var dismissButton: some View {
        Button {
            appReviewService.recordDismissed()
            dismiss()
        } label: {
            Text("Not now")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(.top, AppTheme.Spacing.xxs)
    }
    
    // MARK: - Actions
    
    private func submitFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // TODO: Wire to backend API when endpoint is ready
        #if DEBUG
        print("[AppReviewFlow] Feedback submitted: \(trimmed)")
        #endif
        
        appReviewService.recordDismissed()
        
        withAnimation(AppTheme.Animation.standard) {
            feedbackSubmitted = true
        }
    }
}

// MARK: - Preview

#Preview("Sentiment Check") {
    AppReviewFlowView(appReviewService: MockAppReviewService())
}
