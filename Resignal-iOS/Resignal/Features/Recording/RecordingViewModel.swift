//
//  RecordingViewModel.swift
//  Resignal
//
//  ViewModel for managing audio recording and transcription.
//

import Foundation
import Observation

/// ViewModel for RecordingView
@MainActor
@Observable
final class RecordingViewModel {
    
    // MARK: - Properties
    
    private let recordingService: RecordingService
    private let transcriptionService: TranscriptionService
    private let session: Session?
    
    var recordingState: RecordingState = .idle
    var duration: TimeInterval = 0
    var transcriptText: String = ""
    var audioLevel: Float = 0.0
    var showError: Bool = false
    var errorMessage: String = ""
    var hasPermissions: Bool = false
    var isRequestingPermissions: Bool = false
    
    private var durationTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    /// Transcript saved before pausing, to preserve when resuming
    private var savedTranscriptBeforePause: String = ""
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        recordingState == .recording
    }
    
    var isPaused: Bool {
        recordingState == .paused
    }
    
    var isProcessing: Bool {
        recordingState == .processing
    }
    
    var canRecord: Bool {
        hasPermissions && (recordingState == .idle || recordingState == .paused)
    }
    
    var canPause: Bool {
        recordingState == .recording
    }
    
    var canStop: Bool {
        recordingState == .recording || recordingState == .paused
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    init(
        recordingService: RecordingService,
        transcriptionService: TranscriptionService,
        session: Session? = nil
    ) {
        self.recordingService = recordingService
        self.transcriptionService = transcriptionService
        self.session = session
        
        Task {
            await checkPermissions()
        }
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() async {
        let micPermission = recordingService.hasPermission()
        let speechPermission = await transcriptionService.hasPermission()
        hasPermissions = micPermission && speechPermission
    }
    
    func requestPermissions() async {
        isRequestingPermissions = true
        
        let micGranted = await recordingService.requestPermission()
        let speechGranted = await transcriptionService.requestPermission()
        
        hasPermissions = micGranted && speechGranted
        isRequestingPermissions = false
        
        if !hasPermissions {
            showError(message: "Microphone and speech recognition permissions are required to record.")
        }
    }
    
    // MARK: - Recording Actions
    
    func startRecording() async {
        guard canRecord else { return }
        
        do {
            recordingURL = try await recordingService.startRecording()
            recordingState = recordingService.state
            
            // Reset saved transcript for fresh recording
            savedTranscriptBeforePause = ""
            
            startTimers()
            
            // Start live transcription
            Task {
                await startLiveTranscription()
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    func pauseRecording() async {
        guard canPause else { return }
        
        do {
            try recordingService.pauseRecording()
            recordingState = recordingService.state
            stopTimers()
            
            // Stop live transcription and save current transcript
            savedTranscriptBeforePause = transcriptText
            await transcriptionService.stopLiveTranscription()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    func resumeRecording() async {
        guard isPaused else { return }
        
        do {
            try recordingService.resumeRecording()
            recordingState = recordingService.state
            startTimers()
            
            // Restart live transcription
            Task {
                await startLiveTranscription()
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    func stopRecording() async -> URL? {
        guard canStop else { return nil }
        
        stopTimers()
        
        // Stop live transcription
        await transcriptionService.stopLiveTranscription()
        
        do {
            let url = try await recordingService.stopRecording()
            recordingState = .processing
            
            // Transcribe the complete recording
            await transcribeRecording(url: url)
            
            recordingState = .idle
            savedTranscriptBeforePause = ""
            return url
        } catch {
            showError(message: error.localizedDescription)
            recordingState = .idle
            return nil
        }
    }
    
    func cancelRecording() async {
        stopTimers()
        
        // Stop live transcription
        await transcriptionService.stopLiveTranscription()
        
        do {
            try await recordingService.cancelRecording()
            recordingState = .idle
            duration = 0
            transcriptText = ""
            audioLevel = 0
            recordingURL = nil
            savedTranscriptBeforePause = ""
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Transcription
    
    private func startLiveTranscription() async {
        do {
            let stream = try await transcriptionService.startLiveTranscription()
            
            for await partialTranscript in stream {
                // Combine with any transcript saved before pause
                if savedTranscriptBeforePause.isEmpty {
                    transcriptText = partialTranscript
                } else {
                    transcriptText = savedTranscriptBeforePause + " " + partialTranscript
                }
            }
        } catch {
            // Live transcription failed, will fall back to post-recording transcription
        }
    }
    
    private func transcribeRecording(url: URL) async {
        do {
            let transcript = try await transcriptionService.transcribe(audioURL: url)
            transcriptText = transcript
        } catch {
            // If transcription fails, keep any partial transcript from live transcription
            if transcriptText.isEmpty {
                showError(message: "Transcription failed. You can edit the text manually.")
            }
        }
    }
    
    // MARK: - Timers
    
    private func startTimers() {
        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDuration()
            }
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAudioLevel()
            }
        }
    }
    
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateDuration() {
        duration = recordingService.duration
    }
    
    private func updateAudioLevel() {
        audioLevel = recordingService.getAudioLevel()
    }
    
    // MARK: - Error Handling
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        showError = false
        errorMessage = ""
    }
}
