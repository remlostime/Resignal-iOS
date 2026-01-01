//
//  EmptyStateView.swift
//  Resignal
//
//  Empty state illustration component using SF Symbols.
//

import SwiftUI

/// Empty state view with icon, title, and optional description and action
struct EmptyStateView: View {
    
    // MARK: - Properties
    
    let icon: String
    let title: String
    let description: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    // MARK: - Initialization
    
    init(
        icon: String,
        title: String,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            // Text content
            VStack(spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let description = description {
                    Text(description)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action button
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Common Empty States

extension EmptyStateView {
    /// Empty state for no sessions
    static var noSessions: EmptyStateView {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Sessions Yet",
            description: "Start analyzing your interview responses to get actionable feedback."
        )
    }
    
    /// Empty state for no results
    static var noResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            description: "Try adjusting your search or filters."
        )
    }
    
    /// Empty state for analysis pending
    static var pendingAnalysis: EmptyStateView {
        EmptyStateView(
            icon: "sparkles",
            title: "Ready to Analyze",
            description: "Paste your interview Q&A or transcript to get started."
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        EmptyStateView.noSessions
        
        EmptyStateView(
            icon: "plus.circle",
            title: "Create Your First Session",
            description: "Tap the button below to start",
            actionTitle: "New Session"
        ) {
            print("Action tapped")
        }
    }
}

