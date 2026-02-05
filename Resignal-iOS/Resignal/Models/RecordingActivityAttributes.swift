//
//  RecordingActivityAttributes.swift
//  Resignal
//
//  Activity attributes for the recording Live Activity.
//  This model defines the data structure for displaying recording status
//  on the lock screen and Dynamic Island.
//

import Foundation
import ActivityKit

/// Attributes for the recording Live Activity
struct RecordingActivityAttributes: ActivityAttributes {
    
    /// Static attributes that don't change during the activity lifecycle
    public struct ContentState: Codable, Hashable {
        /// Current recording duration in seconds
        var duration: TimeInterval
        /// Whether the recording is currently paused
        var isPaused: Bool
        /// Formatted duration string (e.g., "02:34")
        var formattedDuration: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Name of the session being recorded (optional)
    var sessionName: String
    /// The start time of the recording
    var startTime: Date
}

// MARK: - Deep Link URL

extension RecordingActivityAttributes {
    /// URL scheme for stopping recording from Live Activity
    static let stopRecordingURL = URL(string: "resignal://stopRecording")!
}
