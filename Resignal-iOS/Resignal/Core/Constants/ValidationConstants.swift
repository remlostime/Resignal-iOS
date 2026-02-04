//
//  ValidationConstants.swift
//  Resignal
//
//  Shared validation constants used across the app.
//

import Foundation

/// Validation constants for input validation
enum ValidationConstants {
    /// Minimum number of characters required for input text analysis
    static let minimumInputCharacters = 1
    
    /// Maximum image size in bytes for API upload (2MB)
    static let maxImageSizeBytes: Int64 = 2 * 1024 * 1024
}

