//
//  AttachmentService.swift
//  Resignal
//
//  Service for managing file and image attachments.
//

import Foundation
import UIKit

/// Errors that can occur during attachment operations
enum AttachmentError: LocalizedError {
    case fileNotFound
    case saveFailed
    case deleteFailed
    case invalidData
    case fileSizeTooLarge
    case unsupportedFileType
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Attachment file not found."
        case .saveFailed:
            return "Failed to save attachment."
        case .deleteFailed:
            return "Failed to delete attachment."
        case .invalidData:
            return "Invalid attachment data."
        case .fileSizeTooLarge:
            return "File size exceeds the maximum allowed limit (10 MB)."
        case .unsupportedFileType:
            return "This file type is not supported."
        }
    }
}

/// Protocol defining attachment management capabilities
protocol AttachmentService: Actor {
    /// Maximum file size in bytes (10 MB)
    static var maxFileSize: Int64 { get }
    
    /// Save an image attachment
    func saveImage(_ image: UIImage, filename: String) async throws -> SessionAttachment
    
    /// Save a file attachment from data
    func saveFile(data: Data, filename: String, type: AttachmentType) async throws -> SessionAttachment
    
    /// Save a file attachment from URL
    func saveFile(from url: URL, type: AttachmentType) async throws -> SessionAttachment
    
    /// Load attachment data
    func loadAttachment(_ attachment: SessionAttachment) async throws -> Data
    
    /// Load image from attachment
    func loadImage(_ attachment: SessionAttachment) async throws -> UIImage
    
    /// Delete an attachment
    func deleteAttachment(_ attachment: SessionAttachment) async throws
    
    /// Delete multiple attachments
    func deleteAttachments(_ attachments: [SessionAttachment]) async throws
    
    /// Generate thumbnail for image
    func generateThumbnail(for image: UIImage, maxSize: CGSize) async -> UIImage
    
    /// Get base64 encoded data for AI processing
    func getBase64Data(_ attachment: SessionAttachment) async throws -> String
    
    /// Get MIME type for an attachment
    func getMimeType(_ attachment: SessionAttachment) async -> String
    
    /// Compress image to ensure it's under maxBytes, returns compressed JPEG data
    func compressImageForUpload(_ image: UIImage, maxBytes: Int64) async -> Data?
}
