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
    @State private var fullscreenImage: UIImage?
    @State private var showFullscreenImage = false
    @State private var showPaywall = false
    
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
        .onAppear {
            if viewModel == nil {
                viewModel = ResultViewModel(
                    session: session,
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
            .onChange(of: viewModel.selectedTab) { _, newTab in
                if newTab == .ask {
                    Task {
                        await viewModel.loadMessages()
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .fullScreenCover(isPresented: $showFullscreenImage) {
            FullscreenImageView(image: fullscreenImage) {
                showFullscreenImage = false
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func feedbackTabContent(viewModel: ResultViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Session info
                sessionInfoView
                
                // Feedback content
                if let feedback = session.structuredFeedback {
                    FeedbackSectionsView(
                        feedback: feedback,
                        featureAccessService: container.featureAccessService,
                        onUpgradeTapped: { showPaywall = true }
                    )
                } else {
                    emptyFeedbackView
                }
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
                            if attachment.attachmentType == .image {
                                ImageAttachmentRow(
                                    attachment: attachment,
                                    attachmentService: container.attachmentService,
                                    onTap: { image in
                                        fullscreenImage = image
                                        showFullscreenImage = true
                                    }
                                )
                            } else {
                                // Non-image attachment (files)
                                HStack {
                                    Image(systemName: "doc")
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
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    @ViewBuilder
    private func askTabContent(viewModel: ResultViewModel) -> some View {
        if container.featureAccessService.canUseAskTab() {
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
                onSend: {
                    Task {
                        await viewModel.sendAskMessage()
                    }
                }
            )
        } else {
            lockedAskTabView
        }
    }
    
    private var lockedAskTabView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Follow-up Questions")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Unlock Pro to ask AI follow-up questions about your interview performance")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            PrimaryButton("Unlock Pro", icon: "star.fill") {
                showPaywall = true
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            
            Spacer()
            Spacer()
        }
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
            
            Text("This session has not been analyzed")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Image Attachment Row

/// Row view for displaying image attachment with thumbnail
struct ImageAttachmentRow: View {
    let attachment: SessionAttachment
    let attachmentService: AttachmentService
    let onTap: (UIImage) -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button {
            if let image = thumbnailImage {
                onTap(image)
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Thumbnail preview
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 60, height: 60)
                    
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                    } else {
                        ProgressView()
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Image attached")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(attachment.fileSizeFormatted)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text("Tap to view")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.sm)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        }
        .buttonStyle(.plain)
        .task {
            thumbnailImage = try? await attachmentService.loadImage(attachment)
        }
    }
}

// MARK: - Fullscreen Image View

/// Fullscreen image viewer with dismiss capability
struct FullscreenImageView: View {
    let image: UIImage?
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit zoom range
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 4.0 {
                                    withAnimation {
                                        scale = 4.0
                                        lastScale = 4.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(AppTheme.Spacing.md)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Accessibility Identifiers

enum ResultAccessibility {
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
