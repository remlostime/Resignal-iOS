//
//  EditorView.swift
//  Resignal
//
//  Screen for creating or editing a session.
//

import SwiftUI
import PhotosUI

/// Editor screen for creating or editing interview sessions
struct EditorView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    let initialTranscript: String?
    let audioURL: URL?
    
    @State private var viewModel: EditorViewModel?
    @FocusState private var isTextEditorFocused: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessingImage = false
    
    // MARK: - Initialization
    
    init(initialTranscript: String? = nil, audioURL: URL? = nil) {
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
        .navigationTitle("New Session")
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
                    attachmentService: container.attachmentService,
                    featureAccessService: container.featureAccessService,
                    appReviewService: container.appReviewService,
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
        .onChange(of: selectedPhoto) { _, newValue in
            if let item = newValue {
                Task {
                    await processSelectedPhoto(item)
                }
            }
        }
        .overlay {
            if isProcessingImage {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView()
                        Text("Compressing image...")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Spacing.lg)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                }
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
            }
            
            if let imageAttachment = viewModel.attachments.first(where: { $0.attachmentType == .image }) {
                AttachmentChipView(attachment: imageAttachment) {
                    viewModel.removeAttachment(imageAttachment)
                }
            } else {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.Colors.primary)
                        Text("Add Image")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.primary)
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
                    if let interviewId = await viewModel.analyze() {
                        router.replace(with: .interviewDetail(interviewId: interviewId))
                    }
                }
            }
            .accessibilityIdentifier(EditorAccessibility.analyzeButton)
        }
    }
    
    // MARK: - Image Processing
    
    private func processSelectedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isProcessingImage = true
        }
        
        defer {
            Task { @MainActor in
                isProcessingImage = false
                selectedPhoto = nil
            }
        }
        
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        
        // Compress image to fit within 2MB limit
        guard let compressedData = await container.attachmentService.compressImageForUpload(
            image,
            maxBytes: ValidationConstants.maxImageSizeBytes
        ) else {
            return
        }
        
        let filename = "image_\(UUID().uuidString).jpg"
        
        if let attachment = try? await container.attachmentService.saveFile(
            data: compressedData,
            filename: filename,
            type: .image
        ) {
            await MainActor.run {
                guard let viewModel = viewModel else { return }
                viewModel.attachments.removeAll { $0.attachmentType == .image }
                viewModel.attachments.append(attachment)
            }
        }
    }
}

/// Chip view for displaying image attachment with thumbnail
struct AttachmentChipView: View {
    let attachment: SessionAttachment
    let onRemove: () -> Void
    @State private var thumbnailImage: UIImage?
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 50, height: 50)
                
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Image attached")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(attachment.fileSizeFormatted)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .task {
            if attachment.attachmentType == .image {
                thumbnailImage = try? await container.attachmentService.loadImage(attachment)
            }
        }
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
        EditorView()
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}
