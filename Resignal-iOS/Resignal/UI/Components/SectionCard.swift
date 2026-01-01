//
//  SectionCard.swift
//  Resignal
//
//  Expandable section card for displaying grouped content.
//

import SwiftUI

/// A card component for grouping related content with optional expansion
struct SectionCard<Content: View>: View {
    
    // MARK: - Properties
    
    let title: String
    let icon: String?
    let isExpandable: Bool
    @ViewBuilder let content: () -> Content
    
    @State private var isExpanded: Bool = true
    
    // MARK: - Initialization
    
    init(
        title: String,
        icon: String? = nil,
        isExpandable: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isExpandable = isExpandable
        self.content = content
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
            
            // Content
            if isExpanded || !isExpandable {
                Divider()
                    .background(AppTheme.Colors.divider)
                
                content()
                    .padding(AppTheme.Spacing.md)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        Button {
            if isExpandable {
                withAnimation(AppTheme.Animation.spring) {
                    isExpanded.toggle()
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if isExpandable {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .padding(AppTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isExpandable)
    }
}

/// Disclosure group styled consistently with the app theme
struct ThemedDisclosureGroup<Label: View, Content: View>: View {
    
    @Binding var isExpanded: Bool
    @ViewBuilder let label: () -> Label
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(AppTheme.Animation.spring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    label()
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content()
                    .padding(.top, AppTheme.Spacing.sm)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            SectionCard(title: "Summary", icon: "doc.text") {
                Text("This is the content of the section card.")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            SectionCard(title: "Expandable Section", icon: "chevron.down.circle", isExpandable: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• First item")
                    Text("• Second item")
                    Text("• Third item")
                }
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding()
    }
}

