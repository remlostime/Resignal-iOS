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
    
    let onComplete: ((URL, String, UUID?) -> Void)?
    
    @State private var viewModel: RecordingViewModel?
    @State private var showRecordingNotice = false
    @State private var showCopiedToast = false
    
    // MARK: - Initialization
    
    init(onComplete: ((URL, String, UUID?) -> Void)? = nil) {
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
                let vm = RecordingViewModel(
                    recordingService: container.recordingService,
                    transcriptionService: container.transcriptionService,
                    audioUploadService: container.audioUploadService,
                    audioCacheService: container.audioCacheService,
                    audioAPI: container.settingsService.audioAPI,
                    liveActivityService: container.liveActivityService
                )
                
                vm.onStopFromLiveActivity = { [onComplete] url, transcript, recordingId in
                    if let onComplete = onComplete {
                        onComplete(url, transcript, recordingId)
                    }
                }
                
                viewModel = vm
            }
            
            if !container.settingsService.hasSeenRecordingNotice {
                showRecordingNotice = true
            }
        }
        .sheet(isPresented: $showRecordingNotice) {
            RecordingTransparencyNotice {
                container.settingsService.hasSeenRecordingNotice = true
                showRecordingNotice = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onChange(of: viewModel?.liveActivityFailedRecordingId) { _, recordingId in
            if let recordingId {
                router.replace(with: .draft(recordingId: recordingId))
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
                if viewModel.transcriptText.isEmpty {
                    Text("Transcription will appear here...")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Spacing.sm)
                } else {
                    SelectableTextView(text: viewModel.transcriptText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(AppTheme.Animation.standard) {
                            showCopiedToast = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.sm)
                }
            }
            .frame(height: 150)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        }
        .toast(isPresented: $showCopiedToast, message: "Copied!")
    }
    
    private func controlsView(viewModel: RecordingViewModel) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.lg) {
                if viewModel.isRecording || viewModel.isPaused {
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
                
                Button {
                    Task {
                        if viewModel.isRecording || viewModel.isPaused {
                            if let url = await viewModel.stopRecording() {
                                if viewModel.canRetry, let recordingId = viewModel.currentRecordingId {
                                    router.replace(with: .draft(recordingId: recordingId))
                                } else if let onComplete = onComplete {
                                    onComplete(url, viewModel.transcriptText, viewModel.currentRecordingId)
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

// MARK: - Recording Transparency Notice

/// One-time modal shown before the first recording to inform the user about audio processing.
struct RecordingTransparencyNotice: View {
    
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.primary)
            
            Text("Your audio will be securely processed to generate transcript and AI feedback.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            Spacer()
            
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .background(AppTheme.Colors.background)
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
