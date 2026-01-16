//
//  AttachmentPickerView.swift
//  Resignal
//
//  Component for picking images and files to attach to sessions.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// View for selecting images and files to attach
struct AttachmentPickerView: View {
    
    @Binding var selectedAttachments: [SessionAttachment]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: AttachmentTab = .images
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isDocumentPickerPresented = false
    @State private var isProcessing = false
    
    let attachmentService: AttachmentService
    
    enum AttachmentTab {
        case images
        case files
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Attachment Type", selection: $selectedTab) {
                    Text("Images").tag(AttachmentTab.images)
                    Text("Files").tag(AttachmentTab.files)
                }
                .pickerStyle(.segmented)
                .padding(AppTheme.Spacing.md)
                
                // Content
                Group {
                    switch selectedTab {
                    case .images:
                        imagesTab
                    case .files:
                        filesTab
                    }
                }
            }
            .navigationTitle("Add Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView("Processing...")
                            .padding(AppTheme.Spacing.lg)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                    }
                }
            }
        }
    }
    
    private var imagesTab: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label("Select Photos", systemImage: "photo.on.rectangle")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    await processSelectedPhotos(newValue)
                }
            }
            
            if !selectedAttachments.filter({ $0.attachmentType == .image }).isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppTheme.Spacing.sm) {
                        ForEach(selectedAttachments.filter { $0.attachmentType == .image }, id: \.id) { attachment in
                            AttachmentThumbnailView(
                                attachment: attachment,
                                onRemove: {
                                    removeAttachment(attachment)
                                }
                            )
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            } else {
                Spacer()
                Text("No images selected")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                Spacer()
            }
        }
    }
    
    private var filesTab: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                isDocumentPickerPresented = true
            } label: {
                Label("Select Files", systemImage: "doc.on.doc")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.pdf, .plainText, .data],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await processSelectedFiles(result)
                }
            }
            
            if !selectedAttachments.filter({ $0.attachmentType == .file }).isEmpty {
                List {
                    ForEach(selectedAttachments.filter { $0.attachmentType == .file }, id: \.id) { attachment in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text(attachment.filename)
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                Text(attachment.fileSizeFormatted)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                            }
                            
                            Spacer()
                            
                            Button {
                                removeAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                Spacer()
                Text("No files selected")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                Spacer()
            }
        }
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                
                let filename = "image_\(UUID().uuidString).jpg"
                
                if let attachment = try? await attachmentService.saveImage(image, filename: filename) {
                    await MainActor.run {
                        selectedAttachments.append(attachment)
                    }
                }
            }
        }
        
        await MainActor.run {
            isProcessing = false
            selectedPhotos = []
        }
    }
    
    private func processSelectedFiles(_ result: Result<[URL], Error>) async {
        isProcessing = true
        
        switch result {
        case .success(let urls):
            for url in urls {
                if let attachment = try? await attachmentService.saveFile(from: url, type: .file) {
                    await MainActor.run {
                        selectedAttachments.append(attachment)
                    }
                }
            }
        case .failure:
            break
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    private func removeAttachment(_ attachment: SessionAttachment) {
        selectedAttachments.removeAll { $0.id == attachment.id }
        
        Task {
            try? await attachmentService.deleteAttachment(attachment)
        }
    }
}

/// Thumbnail view for an attachment
struct AttachmentThumbnailView: View {
    let attachment: SessionAttachment
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(AppTheme.Colors.surface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if attachment.attachmentType == .image {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .padding(AppTheme.Spacing.xxs)
            }
        }
    }
}
