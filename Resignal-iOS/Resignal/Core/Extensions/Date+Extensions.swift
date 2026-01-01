//
//  Date+Extensions.swift
//  Resignal
//
//  Date formatting extensions for consistent display.
//

import Foundation

extension Date {
    
    // MARK: - Cached Formatters
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let mediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Formatted Strings
    
    /// Returns a relative formatted string (e.g., "Today", "Yesterday", "2 days ago")
    var relativeFormatted: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a short formatted date string
    var shortFormatted: String {
        Self.shortFormatter.string(from: self)
    }
    
    /// Returns a medium formatted date string
    var mediumFormatted: String {
        Self.mediumFormatter.string(from: self)
    }
}
