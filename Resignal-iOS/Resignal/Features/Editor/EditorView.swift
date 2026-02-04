//
//  EditorView.swift
//  Resignal
//
//  Screen for creating or editing a session.
//

import SwiftUI

/// Editor screen for creating or editing interview sessions
struct EditorView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    let existingSession: Session?
    let initialTranscript: String?
    let audioURL: URL?
    
    @State private var viewModel: EditorViewModel?
    @FocusState private var isTextEditorFocused: Bool
    
    // MARK: - Initialization
    
    init(existingSession: Session? = nil, initialTranscript: String? = nil, audioURL: URL? = nil) {
        self.existingSession = existingSession
        self.initialTranscript = initialTranscript
        self.audioURL = audioURL
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                editorContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(existingSession == nil ? "New Session" : "Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel?.isAnalyzing ?? false)
        .toolbar {
            if viewModel?.isAnalyzing == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        viewModel?.cancelAnalysis()
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EditorViewModel(
                    aiClient: container.aiClient,
                    sessionRepository: container.sessionRepository,
                    attachmentService: container.attachmentService,
                    session: existingSession,
                    initialTranscript: initialTranscript,
                    audioURL: audioURL
                )
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
    private func editorContent(viewModel: EditorViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Text input section
            textInputSection(viewModel: viewModel)
            
            // Attachments section
            attachmentsSection(viewModel: viewModel)
            
            // Action buttons
            actionSection(viewModel: viewModel)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .sheet(isPresented: Binding(
            get: { viewModel.showAttachmentPicker },
            set: { viewModel.showAttachmentPicker = $0 }
        )) {
            AttachmentPickerView(
                selectedAttachments: Binding(
                    get: { viewModel.attachments },
                    set: { viewModel.attachments = $0 }
                ),
                attachmentService: container.attachmentService
            )
        }
    }
    
    private func textInputSection(viewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text("Interview Q&A / Transcript")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text(viewModel.characterCountMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(
                        viewModel.canAnalyze
                            ? AppTheme.Colors.textTertiary
                            : AppTheme.Colors.destructive
                    )
            }
            
            TextEditor(text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ))
            .font(AppTheme.Typography.body)
            .focused($isTextEditorFocused)
            .frame(maxHeight: .infinity)
            .padding(AppTheme.Spacing.sm)
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            .accessibilityIdentifier(EditorAccessibility.textEditor)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .strokeBorder(
                        isTextEditorFocused
                            ? AppTheme.Colors.primary
                            : AppTheme.Colors.border,
                        lineWidth: isTextEditorFocused ? 2 : 1
                    )
            )
            .overlay(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Paste or type your interview questions and answers here...")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .padding(AppTheme.Spacing.sm)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func attachmentsSection(viewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text("Image Attachment")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Text("(optional, 1 max)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Spacer()
                
                if viewModel.attachments.first(where: { $0.attachmentType == .image }) == nil {
                    Button {
                        viewModel.toggleAttachmentPicker()
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
            
            if let imageAttachment = viewModel.attachments.first(where: { $0.attachmentType == .image }) {
                AttachmentChipView(attachment: imageAttachment) {
                    viewModel.removeAttachment(imageAttachment)
                }
            } else {
                Button {
                    viewModel.toggleAttachmentPicker()
                } label: {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        Text("Add image for analysis")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
            }
        }
    }
    
    private func actionSection(viewModel: EditorViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if viewModel.isAnalyzing {
                // Progress view
                VStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView(value: viewModel.analysisProgress)
                        .tint(AppTheme.Colors.primary)
                    
                    Text("Analyzing your responses...")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .padding(AppTheme.Spacing.md)
            }
            
            PrimaryButton(
                "Analyze",
                icon: "sparkles",
                isLoading: viewModel.isAnalyzing,
                isDisabled: !viewModel.canAnalyze
            ) {
                Task {
                    isTextEditorFocused = false
                    if let session = await viewModel.analyze() {
                        router.replace(with: .result(session: session))
                    }
                }
            }
            .accessibilityIdentifier(EditorAccessibility.analyzeButton)
        }
    }
}

/// Chip view for displaying attachments
struct AttachmentChipView: View {
    let attachment: SessionAttachment
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: attachment.attachmentType == .image ? "photo" : "doc")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text(attachment.filename)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full))
    }
}

// MARK: - Accessibility Identifiers

enum EditorAccessibility {
    static let roleTextField = "roleTextField"
    static let rubricPicker = "rubricPicker"
    static let textEditor = "textEditor"
    static let analyzeButton = "analyzeButton"
    static let characterCount = "characterCount"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditorView(existingSession: nil)
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}

