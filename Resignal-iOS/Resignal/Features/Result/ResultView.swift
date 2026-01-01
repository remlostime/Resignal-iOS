//
//  ResultView.swift
//  Resignal
//
//  Screen displaying the analysis results.
//

import SwiftUI

/// Result screen showing structured feedback
struct ResultView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    
    let session: Session
    
    @State private var viewModel: ResultViewModel?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                resultContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel?.copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        viewModel?.showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        router.navigate(to: .editor(session: session))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ResultViewModel(
                    session: session,
                    aiClient: container.aiClient,
                    sessionRepository: container.sessionRepository
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showShareSheet ?? false },
            set: { viewModel?.showShareSheet = $0 }
        )) {
            if let viewModel = viewModel {
                ShareSheet(items: [viewModel.shareText])
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { viewModel?.showError = $0 }
        )) {
            Button("OK") {
                viewModel?.showError = false
            }
        } message: {
            Text(viewModel?.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func resultContent(viewModel: ResultViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Session info
                sessionInfoView
                
                // Feedback sections
                feedbackSections(viewModel: viewModel)
                
                // Action buttons
                actionButtons(viewModel: viewModel)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
    
    private var sessionInfoView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                if let role = session.role, !role.isEmpty {
                    Label(role, systemImage: "person.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text(session.createdAt.mediumFormatted)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            
            if !session.tags.isEmpty {
                TagChipsView(tags: session.tags)
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardStyle()
    }
    
    @ViewBuilder
    private func feedbackSections(viewModel: ResultViewModel) -> some View {
        @Bindable var bindableVM = viewModel
        let sections = viewModel.sections

        // Summary
        if !sections.summary.isEmpty {
            FeedbackSectionView(
                title: "Summary",
                icon: "doc.text",
                content: sections.summary,
                isExpanded: $bindableVM.isSummaryExpanded
            )
        }

        // Strengths
        if !sections.strengths.isEmpty {
            FeedbackSectionView(
                title: "Strengths",
                icon: "star.fill",
                content: sections.strengths,
                isExpanded: $bindableVM.isStrengthsExpanded
            )
        }

        // Weaknesses
        if !sections.weaknesses.isEmpty {
            FeedbackSectionView(
                title: "Weaknesses",
                icon: "exclamationmark.triangle",
                content: sections.weaknesses,
                isExpanded: $bindableVM.isWeaknessesExpanded
            )
        }

        // Suggested Answers
        if !sections.suggestedAnswers.isEmpty {
            FeedbackSectionView(
                title: "Suggested Improved Answers",
                icon: "lightbulb.fill",
                content: sections.suggestedAnswers,
                isExpanded: $bindableVM.isSuggestedExpanded
            )
        }

        // Follow-up Questions
        if !sections.followUpQuestions.isEmpty {
            FeedbackSectionView(
                title: "Follow-up Questions",
                icon: "questionmark.circle",
                content: sections.followUpQuestions,
                isExpanded: $bindableVM.isFollowUpExpanded
            )
        }
    }
    
    private func actionButtons(viewModel: ResultViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            PrimaryButton(
                "Regenerate",
                icon: "arrow.clockwise",
                isLoading: viewModel.isRegenerating,
                style: .outlined
            ) {
                Task {
                    await viewModel.regenerate()
                }
            }
            .accessibilityIdentifier(ResultAccessibility.regenerateButton)

            HStack(spacing: AppTheme.Spacing.sm) {
                PrimaryButton("Copy", icon: "doc.on.doc", style: .text) {
                    viewModel.copyToClipboard()
                }
                .accessibilityIdentifier(ResultAccessibility.copyButton)

                PrimaryButton("Share", icon: "square.and.arrow.up", style: .text) {
                    viewModel.showShareSheet = true
                }
                .accessibilityIdentifier(ResultAccessibility.shareButton)
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }
}

/// Individual feedback section view
struct FeedbackSectionView: View {

    let title: String
    let icon: String
    let content: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(AppTheme.Animation.spring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(AppTheme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(AppTheme.Colors.divider)

                Text(content)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(AppTheme.Spacing.md)
                    .textSelection(.enabled)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("feedbackSection_\(title.replacingOccurrences(of: " ", with: ""))")
    }
}

// MARK: - Accessibility Identifiers

enum ResultAccessibility {
    static let summarySection = "feedbackSection_Summary"
    static let strengthsSection = "feedbackSection_Strengths"
    static let weaknessesSection = "feedbackSection_Weaknesses"
    static let suggestedSection = "feedbackSection_SuggestedImprovedAnswers"
    static let followUpSection = "feedbackSection_Follow-upQuestions"
    static let copyButton = "copyButton"
    static let shareButton = "shareButton"
    static let regenerateButton = "regenerateButton"
}

/// Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView(session: Session.sampleWithAnalysis)
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}

