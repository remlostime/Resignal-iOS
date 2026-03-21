//
//  ToastView.swift
//  Resignal
//
//  Reusable toast overlay for transient feedback (e.g. "Copied!").
//

import SwiftUI

struct ToastView: View {

    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(AppTheme.Typography.callout.weight(.semibold))

            Text(message)
                .font(AppTheme.Typography.callout.weight(.medium))
        }
        .foregroundStyle(AppTheme.Colors.background)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.primary.opacity(0.9))
        .clipShape(Capsule())
        .subtleShadow()
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {

    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                ToastView(message: message, icon: icon)
                    .padding(.bottom, AppTheme.Spacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(AppTheme.Animation.standard) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(AppTheme.Animation.spring, value: isPresented)
    }
}

extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        duration: TimeInterval = 1.5
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            icon: icon,
            duration: duration
        ))
    }
}

// MARK: - Preview

#Preview {
    ToastView(message: "Copied!", icon: "checkmark.circle.fill")
}
