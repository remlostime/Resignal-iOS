//
//  RecordingLiveActivity.swift
//  RecordingActivityWidget
//
//  Live Activity UI for recording indicator on lock screen and Dynamic Island.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for recording
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        RecordingIndicator()
                        Text("Recording")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedDuration)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Text(context.attributes.sessionName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Link(destination: RecordingActivityAttributes.stopRecordingURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.caption)
                                Text("Stop")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading - recording indicator
                HStack(spacing: 4) {
                    RecordingIndicator(size: 8)
                    Text("REC")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.red)
            } compactTrailing: {
                // Compact trailing - duration
                Text(context.state.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .monospacedDigit()
            } minimal: {
                // Minimal - just the recording indicator
                RecordingIndicator(size: 10)
            }
        }
    }
}

// MARK: - Lock Screen View

/// Lock screen banner view for the Live Activity
struct LockScreenView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon placeholder / recording indicator
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            
            // Recording info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    RecordingIndicator(size: 8)
                    Text("Recording...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(context.state.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Stop button
            Link(destination: RecordingActivityAttributes.stopRecordingURL) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("Stop")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Recording Indicator

/// Pulsing recording indicator dot
struct RecordingIndicator: View {
    var size: CGFloat = 10
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: size, height: size)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: RecordingActivityAttributes.preview) {
    RecordingLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState(duration: 125, isPaused: false)
}

// MARK: - Preview Helpers

extension RecordingActivityAttributes {
    static var preview: RecordingActivityAttributes {
        RecordingActivityAttributes(
            sessionName: "Interview Recording",
            startTime: Date()
        )
    }
}
