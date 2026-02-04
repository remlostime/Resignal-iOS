//
//  AttachmentPickerView.swift
//  Resignal
//
//  Component for picking a single image to attach to sessions.
//

import SwiftUI
import PhotosUI

/// View for selecting a single image to attach (API supports only 1 image, max 2MB)
struct AttachmentPickerView: View {
    
    @Binding var selectedAttachments: [SessionAttachment]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var displayImage: UIImage?
    
    let attachmentService: AttachmentService
    
    /// Returns the current image attachment if one exists
    private var currentImageAttachment: SessionAttachment? {
        selectedAttachments.first { $0.attachmentType == .image }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Hint about limitation
                Text("You can attach 1 image (auto-compressed to fit 2MB limit)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                
                // Photo picker or current image
                if let attachment = currentImageAttachment {
                    // Show current image with option to remove/replace
                    currentImageView(attachment: attachment)
                } else {
                    // Show picker
                    photoPickerButton
                }
                
                Spacer()
            }
            .navigationTitle("Add Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
    }
    
    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .images
        ) {
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text("Select Photo")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.xl)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .onChange(of: selectedPhoto) { _, newValue in
            if let item = newValue {
                Task {
                    await processSelectedPhoto(item)
                }
            }
        }
    }
    
    private func currentImageView(attachment: SessionAttachment) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Image preview
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(4/3, contentMode: .fit)
                
                if let displayImage = displayImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4/3, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .task {
                // Load the image when view appears
                if displayImage == nil {
                    displayImage = try? await attachmentService.loadImage(attachment)
                }
            }
            
            // Action buttons
            HStack(spacing: AppTheme.Spacing.md) {
                // Replace button
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    if let item = newValue {
                        Task {
                            await processSelectedPhoto(item)
                        }
                    }
                }
                
                // Remove button
                Button {
                    removeAttachment(attachment)
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.destructive)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
            }
        }
    }
    
    private func processSelectedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                selectedPhoto = nil
            }
        }
        
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        
        // Compress image to fit within 2MB limit
        guard let compressedData = await attachmentService.compressImageForUpload(
            image,
            maxBytes: ValidationConstants.maxImageSizeBytes
        ) else {
            return
        }
        
        let filename = "image_\(UUID().uuidString).jpg"
        
        // Save compressed data as file
        if let attachment = try? await attachmentService.saveFile(
            data: compressedData,
            filename: filename,
            type: .image
        ) {
            await MainActor.run {
                // Remove any existing image attachments first (only 1 allowed)
                selectedAttachments.removeAll { $0.attachmentType == .image }
                selectedAttachments.append(attachment)
                // Update display image
                displayImage = image
            }
        }
    }
    
    private func removeAttachment(_ attachment: SessionAttachment) {
        selectedAttachments.removeAll { $0.id == attachment.id }
        displayImage = nil
        
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
