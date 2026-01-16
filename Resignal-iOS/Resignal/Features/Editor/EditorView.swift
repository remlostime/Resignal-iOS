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
    
    @State private var viewModel: EditorViewModel?
    @FocusState private var isTextEditorFocused: Bool
    
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
                    session: existingSession
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
    
    private func inputModeSelector(viewModel: EditorViewModel) -> some View {
        Picker("Input Mode", selection: Binding(
            get: { viewModel.inputMode },
            set: { viewModel.inputMode = $0 }
        )) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private func editorContent(viewModel: EditorViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Input mode selector
                inputModeSelector(viewModel: viewModel)
                
                // Configuration section
                configurationSection(viewModel: viewModel)
                
                // Input section (text or recording)
                if viewModel.inputMode == .text {
                    textInputSection(viewModel: viewModel)
                } else {
                    recordingSection(viewModel: viewModel)
                }
                
                // Attachments section
                attachmentsSection(viewModel: viewModel)
                
                // Action buttons
                actionSection(viewModel: viewModel)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
        .scrollDismissesKeyboard(.interactively)
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
    
    private func configurationSection(viewModel: EditorViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Role input
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Role (Optional)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                TextField("e.g., iOS Engineer, Product Manager", text: Binding(
                    get: { viewModel.role },
                    set: { viewModel.role = $0 }
                ))
                .font(AppTheme.Typography.body)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                .accessibilityIdentifier(EditorAccessibility.roleTextField)
            }
            
            // Rubric picker
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Evaluation Rubric")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Menu {
                    ForEach(Rubric.allCases, id: \.self) { rubric in
                        Button(rubric.description) {
                            viewModel.rubric = rubric
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.rubric.description)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
                .accessibilityIdentifier(EditorAccessibility.rubricPicker)
            }
            
            // Tags input
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Tags")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                TagInputField(tags: Binding(
                    get: { viewModel.tags },
                    set: { viewModel.tags = $0 }
                ))
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            }
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
            .frame(minHeight: 300)
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
    
    private func recordingSection(viewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Recording")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            if let audioURL = viewModel.audioURL {
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title)
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text("Recording saved")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            Text(audioURL.lastPathComponent)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                    
                    // Show transcript if available
                    if !viewModel.inputText.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Transcript")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            Text(viewModel.inputText)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .padding(AppTheme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        }
                    }
                }
            } else {
                Button {
                    router.navigate(to: .recording(session: existingSession))
                } label: {
                    Label("Start Recording", systemImage: "mic.circle")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
            }
        }
    }
    
    private func attachmentsSection(viewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text("Attachments")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Button {
                    viewModel.toggleAttachmentPicker()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            
            if !viewModel.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(viewModel.attachments, id: \.id) { attachment in
                            AttachmentChipView(attachment: attachment) {
                                viewModel.removeAttachment(attachment)
                            }
                        }
                    }
                }
            } else {
                Text("No attachments")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
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

