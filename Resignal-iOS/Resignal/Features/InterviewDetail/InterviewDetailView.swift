//
//  InterviewDetailView.swift
//  Resignal
//
//  Server-driven interview detail screen with feedback, transcript, and ask tabs.
//

import SwiftUI

/// Displays interview details fetched from the server
struct InterviewDetailView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    
    let interviewId: String
    
    @State private var viewModel: InterviewDetailViewModel?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                detailContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = InterviewDetailViewModel(
                    interviewId: interviewId,
                    interviewClient: container.interviewClient,
                    chatService: container.chatService,
                    featureAccessService: container.featureAccessService
                )
            }
        }
        .task {
            if let viewModel, viewModel.state.isIdle {
                await viewModel.loadDetail()
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
    private func detailContent(viewModel: InterviewDetailViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack {
                ProgressView()
                Text("Loading interview...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.sm)
            }
            
        case .error(let message):
            errorView(message: message, viewModel: viewModel)
            
        case .success(let feedback):
            loadedContent(feedback: feedback, viewModel: viewModel)
                .navigationTitle(feedback.title)
        }
    }
    
    private func loadedContent(feedback: StructuredFeedback, viewModel: InterviewDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Picker("View", selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 }
            )) {
                ForEach(InterviewDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(AppTheme.Spacing.md)
            
            TabView(selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 }
            )) {
                feedbackTabContent(feedback: feedback)
                    .tag(InterviewDetailTab.feedback)
                
                transcriptTabContent()
                    .tag(InterviewDetailTab.transcript)
                
                askTabContent(viewModel: viewModel)
                    .tag(InterviewDetailTab.ask)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.selectedTab) { _, newTab in
                if newTab == .ask {
                    Task {
                        await viewModel.loadMessages()
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .sheet(isPresented: Binding(
            get: { viewModel.showPaywall },
            set: { viewModel.showPaywall = $0 }
        )) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func feedbackTabContent(feedback: StructuredFeedback) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                FeedbackSectionsView(feedback: feedback)
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    private func transcriptTabContent() -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text("Transcript not available")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Transcript viewing will be available in a future update.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppTheme.Spacing.xl)
                .frame(maxWidth: .infinity)
                .cardStyle()
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    private func askTabContent(viewModel: InterviewDetailViewModel) -> some View {
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
            isLoading: Binding(
                get: { viewModel.isLoadingMessages },
                set: { _ in }
            ),
            isLimitReached: !viewModel.canSendAskMessage,
            onSend: {
                Task {
                    await viewModel.sendAskMessage()
                }
            }
        )
    }
    
    private func errorView(message: String, viewModel: InterviewDetailViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Failed to load interview")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await viewModel.loadDetail()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(AppTheme.Typography.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InterviewDetailView(interviewId: "550e8400-e29b-41d4-a716-446655440000")
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}
