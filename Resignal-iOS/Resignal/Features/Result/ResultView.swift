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
                
                // Feedback content
                if let feedback = session.structuredFeedback {
                    FeedbackSectionsView(feedback: feedback)
                } else {
                    emptyFeedbackView
                }
                
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
    
    private var emptyFeedbackView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("No feedback yet")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Tap 'Regenerate' to analyze this session")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .cardStyle()
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

// MARK: - Accessibility Identifiers

enum ResultAccessibility {
    static let regenerateButton = "regenerateButton"
    static let emptyFeedbackView = "emptyFeedbackView"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView(session: Session.sampleWithAnalysis)
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}
