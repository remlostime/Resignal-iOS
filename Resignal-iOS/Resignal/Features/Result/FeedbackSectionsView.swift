//
//  FeedbackSectionsView.swift
//  Resignal
//
//  View displaying structured feedback in expandable cards.
//

import SwiftUI

/// Displays structured feedback in expandable section cards
struct FeedbackSectionsView: View {
    
    // MARK: - Properties
    
    let feedback: StructuredFeedback
    var featureAccessService: FeatureAccessServiceProtocol?
    var onUpgradeTapped: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Summary Section (Free)
            feedbackSection(.summary) {
                SectionCard(title: "Summary", icon: "doc.text", isExpandable: true) {
                    Text(feedback.summary)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Strengths Section (Free)
            feedbackSection(.strengths) {
                SectionCard(title: "Strengths", icon: "star", isExpandable: true) {
                    BulletListView(items: feedback.strengths)
                }
            }
            
            // Improvements Section (Free)
            feedbackSection(.improvement) {
                SectionCard(title: "Areas for Improvement", icon: "exclamationmark.triangle", isExpandable: true) {
                    BulletListView(items: feedback.improvement)
                }
            }
            
            // Hiring Signal Section (Pro)
            feedbackSection(.hiringSignal) {
                SectionCard(title: "Hiring Signal", icon: "hand.thumbsup", isExpandable: true) {
                    Text(feedback.hiringSignal)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Key Observations Section (Pro)
            feedbackSection(.keyObservations) {
                SectionCard(title: "Key Observations", icon: "eye", isExpandable: true) {
                    BulletListView(items: feedback.keyObservations)
                }
            }
        }
    }
    
    // MARK: - Section Gating
    
    @ViewBuilder
    private func feedbackSection<Content: View>(
        _ section: FeedbackSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let canView = featureAccessService?.canViewFeedbackSection(section) ?? true
        
        if canView {
            content()
        } else {
            LockedSectionCard(
                section: section,
                onUpgradeTapped: onUpgradeTapped
            )
        }
    }
}

// MARK: - Locked Section Card

/// Displays a locked placeholder for Pro-only feedback sections
private struct LockedSectionCard: View {
    let section: FeedbackSection
    var onUpgradeTapped: (() -> Void)?
    
    private var sectionTitle: String {
        switch section {
        case .summary: return "Summary"
        case .strengths: return "Strengths"
        case .improvement: return "Areas for Improvement"
        case .hiringSignal: return "Hiring Signal"
        case .keyObservations: return "Key Observations"
        }
    }
    
    private var sectionIcon: String {
        switch section {
        case .summary: return "doc.text"
        case .strengths: return "star"
        case .improvement: return "exclamationmark.triangle"
        case .hiringSignal: return "hand.thumbsup"
        case .keyObservations: return "eye"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: sectionIcon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text(sectionTitle)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Spacer()
                
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
            
            Divider()
                .background(AppTheme.Colors.divider)
            
            // Locked content placeholder
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "lock.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text("Unlock Pro to view")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                if let onUpgradeTapped {
                    Button {
                        onUpgradeTapped()
                    } label: {
                        Text("Upgrade")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .cardStyle()
        .opacity(0.7)
    }
}

// MARK: - Bullet List View

/// A view that displays a list of items with bullet points
private struct BulletListView: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(items, id: \.self) { item in
                BulletItemView(text: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single bullet item with proper formatting
private struct BulletItemView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Text("•")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            // Parse text to extract title and description if formatted as "Title: Description"
            if let colonIndex = text.firstIndex(of: ":"),
               colonIndex != text.startIndex {
                let title = String(text[..<colonIndex])
                let description = String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    if !description.isEmpty {
                        Text(description)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            } else {
                Text(text)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Accessibility Identifiers

enum FeedbackSectionsAccessibility {
    static let summaryCard = "feedbackSummaryCard"
    static let strengthsCard = "feedbackStrengthsCard"
    static let improvementsCard = "feedbackImprovementsCard"
    static let hiringSignalCard = "feedbackHiringSignalCard"
    static let keyObservationsCard = "feedbackKeyObservationsCard"
}

// MARK: - Preview

#Preview {
    ScrollView {
        FeedbackSectionsView(feedback: .sample)
            .padding(AppTheme.Spacing.md)
    }
    .background(AppTheme.Colors.background)
}
