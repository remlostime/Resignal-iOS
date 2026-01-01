//
//  Date+Extensions.swift
//  Resignal
//
//  Date formatting extensions for consistent display.
//

import Foundation

extension Date {
    /// Returns a relative formatted string (e.g., "Today", "Yesterday", "2 days ago")
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a short formatted date string
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns a medium formatted date string
    var mediumFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

