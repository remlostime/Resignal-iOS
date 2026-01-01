//
//  PrimaryButton.swift
//  Resignal
//
//  Primary action button component with consistent styling.
//

import SwiftUI

/// Primary button style following the app's minimalist aesthetic
struct PrimaryButton: View {
    
    // MARK: - Properties
    
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let style: Style
    let action: () -> Void
    
    enum Style {
        case filled
        case outlined
        case text
    }
    
    // MARK: - Initialization
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        style: Style = .filled,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.style = style
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .tint(foregroundColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                
                Text(title)
                    .font(AppTheme.Typography.headline)
            }
            .frame(maxWidth: style == .text ? nil : .infinity)
            .padding(.horizontal, style == .text ? AppTheme.Spacing.xs : AppTheme.Spacing.md)
            .padding(.vertical, style == .text ? AppTheme.Spacing.xxs : AppTheme.Spacing.sm)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(borderOverlay)
        }
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled && !isLoading) ? 0.5 : 1.0)
        .animation(AppTheme.Animation.fast, value: isLoading)
        .animation(AppTheme.Animation.fast, value: isDisabled)
    }
    
    // MARK: - Computed Properties
    
    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .outlined, .text:
            return AppTheme.Colors.primary
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .filled:
            return AppTheme.Colors.primary
        case .outlined, .text:
            return .clear
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .outlined:
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.primary, lineWidth: 1.5)
        case .filled, .text:
            EmptyView()
        }
    }
}

// MARK: - Destructive Button

struct DestructiveButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(AppTheme.Typography.headline)
            }
            .foregroundStyle(AppTheme.Colors.destructive)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PrimaryButton("Analyze", icon: "sparkles") {}
        PrimaryButton("Analyzing...", isLoading: true) {}
        PrimaryButton("Disabled", isDisabled: true) {}
        PrimaryButton("Outlined", style: .outlined) {}
        PrimaryButton("Text Style", style: .text) {}
        DestructiveButton("Delete", icon: "trash") {}
    }
    .padding()
}

