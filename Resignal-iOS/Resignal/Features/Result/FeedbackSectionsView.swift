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
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Summary Section
            SectionCard(title: "Summary", icon: "doc.text", isExpandable: true) {
                Text(feedback.summary)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Strengths Section
            SectionCard(title: "Strengths", icon: "star", isExpandable: true) {
                BulletListView(items: feedback.strengths)
            }
            
            // Improvements Section
            SectionCard(title: "Areas for Improvement", icon: "exclamationmark.triangle", isExpandable: true) {
                BulletListView(items: feedback.improvement)
            }
            
            // Hiring Signal Section
            SectionCard(title: "Hiring Signal", icon: "hand.thumbsup", isExpandable: true) {
                Text(feedback.hiringSignal)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Key Observations Section
            SectionCard(title: "Key Observations", icon: "eye", isExpandable: true) {
                BulletListView(items: feedback.keyObservations)
            }
        }
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
