//
//  AppTheme.swift
//  Resignal
//
//  Design system and theme constants for consistent styling.
//

import SwiftUI

/// App-wide theme constants following a black & white minimalist aesthetic
enum AppTheme {
    
    // MARK: - Colors
    
    enum Colors {
        static let primary = Color.black
        static let secondary = Color.gray
        static let background = Color.white
        static let surface = Color(uiColor: .systemGray6)
        static let border = Color.gray.opacity(0.2)
        static let divider = Color.gray.opacity(0.15)
        static let textPrimary = Color.black
        static let textSecondary = Color.gray
        static let textTertiary = Color.gray.opacity(0.6)
        static let destructive = Color.red
        static let success = Color.green
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        static let full: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let subtle = ShadowStyle(
            color: .black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let medium = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 4
        )
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let footnote = Font.footnote
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a subtle shadow style
    func subtleShadow() -> some View {
        let style = AppTheme.Shadow.subtle
        return self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    /// Applies a medium shadow style
    func mediumShadow() -> some View {
        let style = AppTheme.Shadow.medium
        return self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    /// Conditionally applies a view modifier
    @ViewBuilder
    func conditionally<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies card-like styling with background and rounded corners
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
            )
    }
}

