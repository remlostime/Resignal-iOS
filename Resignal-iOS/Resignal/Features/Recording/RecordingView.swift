//
//  RecordingView.swift
//  Resignal
//
//  Screen for recording audio with real-time transcription.
//

import SwiftUI

/// Recording screen with audio capture and transcription
struct RecordingView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    let existingSession: Session?
    let onComplete: ((URL, String) -> Void)?
    
    @State private var viewModel: RecordingViewModel?
    
    // MARK: - Initialization
    
    init(existingSession: Session? = nil, onComplete: ((URL, String) -> Void)? = nil) {
        self.existingSession = existingSession
        self.onComplete = onComplete
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                recordingContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Record Interview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel?.isRecording ?? false)
        .toolbar {
            if viewModel?.isRecording == true || viewModel?.isPaused == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        Task {
                            await viewModel?.cancelRecording()
                            dismiss()
                        }
                    }
                    .foregroundStyle(AppTheme.Colors.destructive)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RecordingViewModel(
                    recordingService: container.recordingService,
                    transcriptionService: container.transcriptionService,
                    session: existingSession
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { viewModel?.showError = $0 }
        )) {
            Button("OK") {
                viewModel?.clearError()
            }
        } message: {
            Text(viewModel?.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func recordingContent(viewModel: RecordingViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            if !viewModel.hasPermissions {
                permissionsView(viewModel: viewModel)
            } else {
                Spacer()
                
                // Timer display
                timerView(viewModel: viewModel)
                
                // Audio level visualization
                audioLevelView(viewModel: viewModel)
                
                Spacer()
                
                // Transcript display
                transcriptView(viewModel: viewModel)
                
                Spacer()
                
                // Recording controls
                controlsView(viewModel: viewModel)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
    }
    
    private func permissionsView(viewModel: RecordingViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("Permissions Required")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Resignal needs microphone and speech recognition access to record and transcribe your interview practice.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            PrimaryButton(
                "Grant Permissions",
                icon: "checkmark.circle",
                isLoading: viewModel.isRequestingPermissions
            ) {
                Task {
                    await viewModel.requestPermissions()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            
            Spacer()
        }
    }
    
    private func timerView(viewModel: RecordingViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(viewModel.formattedDuration)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            if viewModel.isRecording {
                HStack(spacing: AppTheme.Spacing.xxs) {
                    Circle()
                        .fill(AppTheme.Colors.destructive)
                        .frame(width: 8, height: 8)
                    
                    Text("Recording")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            } else if viewModel.isPaused {
                Text("Paused")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else if viewModel.isProcessing {
                Text("Processing...")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private func audioLevelView(viewModel: RecordingViewModel) -> some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index, level: viewModel.audioLevel))
                    .frame(width: 4, height: barHeight(for: index, level: viewModel.audioLevel))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
            }
        }
        .frame(height: 60)
    }
    
    private func barColor(for index: Int, level: Float) -> Color {
        let normalizedIndex = Float(index) / 30.0
        return normalizedIndex < level ? AppTheme.Colors.primary : AppTheme.Colors.border
    }
    
    private func barHeight(for index: Int, level: Float) -> CGFloat {
        let normalizedIndex = Float(index) / 30.0
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 60
        
        if normalizedIndex < level {
            // Vary height based on position for wave effect
            let variation = sin(Float(index) * 0.3) * 0.3 + 0.7
            return baseHeight + (maxHeight - baseHeight) * CGFloat(variation)
        }
        
        return baseHeight
    }
    
    private func transcriptView(viewModel: RecordingViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Live Transcript")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            ScrollView {
                Text(viewModel.transcriptText.isEmpty ? "Transcription will appear here..." : viewModel.transcriptText)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(viewModel.transcriptText.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.sm)
            }
            .frame(height: 150)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        }
    }
    
    private func controlsView(viewModel: RecordingViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Main record/stop button
            HStack(spacing: AppTheme.Spacing.lg) {
                if viewModel.isRecording || viewModel.isPaused {
                    // Pause/Resume button
                    Button {
                        Task {
                            if viewModel.isRecording {
                                await viewModel.pauseRecording()
                            } else {
                                await viewModel.resumeRecording()
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.isRecording ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.Colors.secondary)
                    }
                    .disabled(viewModel.isProcessing)
                }
                
                // Record/Stop button
                Button {
                    Task {
                        if viewModel.isRecording || viewModel.isPaused {
                            if let url = await viewModel.stopRecording() {
                                if let onComplete = onComplete {
                                    // Let the completion handler manage navigation
                                    onComplete(url, viewModel.transcriptText)
                                } else {
                                    dismiss()
                                }
                            }
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording || viewModel.isPaused ? AppTheme.Colors.destructive : AppTheme.Colors.primary)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.isRecording || viewModel.isPaused {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                }
                .disabled(!viewModel.canRecord && !viewModel.canStop || viewModel.isProcessing)
            }
            
            // Action label
            Text(actionLabel(for: viewModel))
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
    
    private func actionLabel(for viewModel: RecordingViewModel) -> String {
        if viewModel.isProcessing {
            return "Processing recording..."
        } else if viewModel.isRecording {
            return "Tap to stop recording"
        } else if viewModel.isPaused {
            return "Tap to finish recording"
        } else {
            return "Tap to start recording"
        }
    }
}

// MARK: - Accessibility Identifiers

enum RecordingAccessibility {
    static let recordButton = "recordButton"
    static let pauseButton = "pauseButton"
    static let stopButton = "stopButton"
    static let transcriptView = "transcriptView"
    static let timerLabel = "timerLabel"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecordingView()
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}
