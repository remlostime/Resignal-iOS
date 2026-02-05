//
//  LiveActivityService.swift
//  Resignal
//
//  Service for managing recording Live Activities on lock screen and Dynamic Island.
//

import Foundation
import ActivityKit

// MARK: - Protocol

/// Protocol defining Live Activity management capabilities
@MainActor
protocol LiveActivityService {
    /// Whether Live Activities are supported on this device
    var isSupported: Bool { get }
    
    /// Whether a recording Live Activity is currently active
    var isActivityActive: Bool { get }
    
    /// Start a new recording Live Activity
    /// - Parameter sessionName: Optional name of the session being recorded
    func startActivity(sessionName: String?) async throws
    
    /// Update the Live Activity with new duration
    /// - Parameters:
    ///   - duration: Current recording duration in seconds
    ///   - isPaused: Whether the recording is paused
    func updateActivity(duration: TimeInterval, isPaused: Bool) async
    
    /// End the current Live Activity
    func endActivity() async
}

// MARK: - Implementation

/// Implementation of LiveActivityService using ActivityKit
@MainActor
final class LiveActivityServiceImpl: LiveActivityService {
    
    // MARK: - Properties
    
    private var currentActivity: Activity<RecordingActivityAttributes>?
    
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    var isActivityActive: Bool {
        currentActivity != nil
    }
    
    // MARK: - Public Methods
    
    func startActivity(sessionName: String?) async throws {
        print("🔴 Live Activity - isSupported: \(isSupported)")
        
        guard isSupported else {
            print("🔴 Live Activity NOT supported on this device")
            return
        }
        
        print("🔴 Starting Live Activity for: \(sessionName ?? "Interview Recording")")
        
        // End any existing activity first
        await endActivity()
        
        let attributes = RecordingActivityAttributes(
            sessionName: sessionName ?? "Interview Recording",
            startTime: Date()
        )
        
        let initialState = RecordingActivityAttributes.ContentState(
            duration: 0,
            isPaused: false
        )
        
        let content = ActivityContent(
            state: initialState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("🟢 Live Activity started successfully! ID: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("🔴 Live Activity FAILED to start: \(error)")
            throw LiveActivityError.failedToStart(error)
        }
    }
    
    func updateActivity(duration: TimeInterval, isPaused: Bool) async {
        guard let activity = currentActivity else {
            return
        }
        
        let updatedState = RecordingActivityAttributes.ContentState(
            duration: duration,
            isPaused: isPaused
        )
        
        let content = ActivityContent(
            state: updatedState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        await activity.update(content)
    }
    
    func endActivity() async {
        guard let activity = currentActivity else {
            return
        }
        
        let finalState = RecordingActivityAttributes.ContentState(
            duration: 0,
            isPaused: false
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )
        
        await activity.end(content, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

// MARK: - Mock Implementation

/// Mock implementation for previews and testing
@MainActor
final class MockLiveActivityService: LiveActivityService {
    
    var isSupported: Bool = true
    var isActivityActive: Bool = false
    
    private(set) var startActivityCalled = false
    private(set) var updateActivityCalled = false
    private(set) var endActivityCalled = false
    private(set) var lastDuration: TimeInterval = 0
    private(set) var lastIsPaused: Bool = false
    
    func startActivity(sessionName: String?) async throws {
        startActivityCalled = true
        isActivityActive = true
    }
    
    func updateActivity(duration: TimeInterval, isPaused: Bool) async {
        updateActivityCalled = true
        lastDuration = duration
        lastIsPaused = isPaused
    }
    
    func endActivity() async {
        endActivityCalled = true
        isActivityActive = false
    }
}

// MARK: - Errors

/// Errors that can occur during Live Activity management
enum LiveActivityError: LocalizedError {
    case failedToStart(Error)
    case notSupported
    
    var errorDescription: String? {
        switch self {
        case .failedToStart(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        case .notSupported:
            return "Live Activities are not supported on this device."
        }
    }
}
