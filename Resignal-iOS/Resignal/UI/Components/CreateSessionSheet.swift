//
//  CreateSessionSheet.swift
//  Resignal
//
//  Action sheet for creating a new session via recording or typing.
//

import SwiftUI

/// Protocol for handling create session actions
protocol CreateSessionActionHandler {
    func onRecordSelected()
    func onTypeSelected()
}

/// Sheet presenting options to create a new session
struct CreateSessionSheet: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    let onRecordSelected: () -> Void
    let onTypeSelected: () -> Void
    
    // MARK: - Initialization
    
    init(
        onRecordSelected: @escaping () -> Void,
        onTypeSelected: @escaping () -> Void
    ) {
        self.onRecordSelected = onRecordSelected
        self.onTypeSelected = onTypeSelected
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Create New Session")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("Choose how you want to provide your interview responses")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.top, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.lg)
            
            // Action buttons
            VStack(spacing: AppTheme.Spacing.sm) {
                ActionButton(
                    icon: "mic.fill",
                    title: "Record Audio",
                    description: "Speak your responses and get them transcribed"
                ) {
                    dismiss()
                    onRecordSelected()
                }
                
                ActionButton(
                    icon: "keyboard",
                    title: "Type Text",
                    description: "Write your responses directly"
                ) {
                    dismiss()
                    onTypeSelected()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(CreateSessionAccessibility.sheet)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.Colors.surface)
                    .clipShape(Circle())
                
                // Text content
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(description)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accessibility Identifiers

enum CreateSessionAccessibility {
    static let sheet = "createSessionSheet"
    static let recordButton = "createSessionRecordButton"
    static let typeButton = "createSessionTypeButton"
}

// MARK: - Preview

#Preview {
    CreateSessionSheet(
        onRecordSelected: { print("Record selected") },
        onTypeSelected: { print("Type selected") }
    )
}
