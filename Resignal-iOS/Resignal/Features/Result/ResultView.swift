//
//  ResultView.swift
//  Resignal
//
//  Screen displaying the analysis results.
//

import SwiftUI
import MarkdownUI

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
                Button {
                    router.navigate(to: .editor(session: session))
                } label: {
                    Text("Edit")
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ResultViewModel(
                    session: session,
                    aiClient: container.aiClient,
                    sessionRepository: container.sessionRepository,
                    chatService: container.chatService
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { viewModel?.showError = $0 }
        )) {
            Button("OK") {
                viewModel?.clearError()
            }
        } message: {
            Text(viewModel?.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func resultContent(viewModel: ResultViewModel) -> some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 }
            )) {
                ForEach(ResultTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(AppTheme.Spacing.md)
            
            // Tab content
            TabView(selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 }
            )) {
                feedbackTabContent(viewModel: viewModel)
                    .tag(ResultTab.feedback)
                
                transcriptTabContent(viewModel: viewModel)
                    .tag(ResultTab.transcript)
                
                askTabContent(viewModel: viewModel)
                    .tag(ResultTab.ask)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(AppTheme.Colors.background)
    }
    
    private func feedbackTabContent(viewModel: ResultViewModel) -> some View {
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
    }
    
    private func transcriptTabContent(viewModel: ResultViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Original Interview")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(session.inputText)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .textSelection(.enabled)
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                
                if session.hasAudioRecording {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        Text("Audio recording available")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
                
                if session.hasAttachments {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Attachments")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        
                        ForEach(session.attachments, id: \.id) { attachment in
                            HStack {
                                Image(systemName: attachment.attachmentType == .image ? "photo" : "doc")
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                
                                Text(attachment.filename)
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                Text(attachment.fileSizeFormatted)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                            }
                            .padding(AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    private func askTabContent(viewModel: ResultViewModel) -> some View {
        AskChatView(
            messages: Binding(
                get: { viewModel.chatMessages },
                set: { viewModel.chatMessages = $0 }
            ),
            inputText: Binding(
                get: { viewModel.askMessage },
                set: { viewModel.askMessage = $0 }
            ),
            isSending: Binding(
                get: { viewModel.isSendingMessage },
                set: { viewModel.isSendingMessage = $0 }
            ),
            onSend: {
                Task {
                    await viewModel.sendAskMessage()
                }
            }
        )
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
        let sections = viewModel.sections

        // Summary
        if !sections.summary.isEmpty {
            FeedbackSectionView(
                title: "Summary",
                icon: "doc.text",
                content: sections.summary,
                isExpanded: viewModel.expansionBinding(for: .summary)
            )
        }

        // Strengths
        if !sections.strengths.isEmpty {
            FeedbackSectionView(
                title: "Strengths",
                icon: "star.fill",
                content: sections.strengths,
                isExpanded: viewModel.expansionBinding(for: .strengths)
            )
        }

        // Weaknesses
        if !sections.weaknesses.isEmpty {
            FeedbackSectionView(
                title: "Weaknesses",
                icon: "exclamationmark.triangle",
                content: sections.weaknesses,
                isExpanded: viewModel.expansionBinding(for: .weaknesses)
            )
        }

        // Hiring Signal
        if !sections.hiringSignal.isEmpty {
            FeedbackSectionView(
                title: "Hiring Signal Assessment",
                icon: "checkmark.seal.fill",
                content: sections.hiringSignal,
                isExpanded: viewModel.expansionBinding(for: .hiringSignal)
            )
        }

        // Suggested Answers
        if !sections.suggestedAnswers.isEmpty {
            FeedbackSectionView(
                title: "Suggested Improved Answers",
                icon: "lightbulb.fill",
                content: sections.suggestedAnswers,
                isExpanded: viewModel.expansionBinding(for: .suggested)
            )
        }

        // Follow-up Questions
        if !sections.followUpQuestions.isEmpty {
            FeedbackSectionView(
                title: "Follow-up Questions",
                icon: "questionmark.circle",
                content: sections.followUpQuestions,
                isExpanded: viewModel.expansionBinding(for: .followUp)
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

                Markdown(content)
                    .markdownTheme(.basic)
                    .markdownTextStyle(\.text) {
                        ForegroundColor(.init(AppTheme.Colors.textSecondary))
                        FontSize(.em(1.0))
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.9))
                        ForegroundColor(.init(AppTheme.Colors.textPrimary))
                        BackgroundColor(.init(AppTheme.Colors.surface))
                    }
                    .markdownTextStyle(\.strong) {
                        FontWeight(.semibold)
                        ForegroundColor(.init(AppTheme.Colors.textPrimary))
                    }
                    .markdownTextStyle(\.emphasis) {
                        FontStyle(.italic)
                    }
                    .markdownBlockStyle(\.paragraph) { configuration in
                        configuration.label
                            .relativeLineSpacing(.em(0.2))
                            .markdownMargin(top: .zero, bottom: .em(0.8))
                    }
                    .markdownBlockStyle(\.heading1) { configuration in
                        configuration.label
                            .markdownTextStyle {
                                FontSize(.em(1.5))
                                FontWeight(.bold)
                                ForegroundColor(.init(AppTheme.Colors.textPrimary))
                            }
                            .markdownMargin(top: .em(0.5), bottom: .em(0.5))
                    }
                    .markdownBlockStyle(\.heading2) { configuration in
                        configuration.label
                            .markdownTextStyle {
                                FontSize(.em(1.3))
                                FontWeight(.semibold)
                                ForegroundColor(.init(AppTheme.Colors.textPrimary))
                            }
                            .markdownMargin(top: .em(0.5), bottom: .em(0.4))
                    }
                    .markdownBlockStyle(\.heading3) { configuration in
                        configuration.label
                            .markdownTextStyle {
                                FontSize(.em(1.15))
                                FontWeight(.semibold)
                                ForegroundColor(.init(AppTheme.Colors.textPrimary))
                            }
                            .markdownMargin(top: .em(0.4), bottom: .em(0.3))
                    }
                    .markdownBlockStyle(\.listItem) { configuration in
                        configuration.label
                            .markdownMargin(top: .em(0.2), bottom: .em(0.2))
                    }
                    .markdownBlockStyle(\.blockquote) { configuration in
                        configuration.label
                            .padding(.leading, AppTheme.Spacing.sm)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(AppTheme.Colors.border)
                                    .frame(width: 3)
                            }
                            .markdownMargin(top: .em(0.5), bottom: .em(0.5))
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        configuration.label
                            .padding(AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                            .markdownMargin(top: .em(0.5), bottom: .em(0.5))
                    }
                    .textSelection(.enabled)
                    .padding(AppTheme.Spacing.md)
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
    static let regenerateButton = "regenerateButton"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView(session: Session.sampleWithAnalysis)
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}
