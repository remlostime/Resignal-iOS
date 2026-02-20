//
//  RecordingViewModel.swift
//  Resignal
//
//  ViewModel for managing audio recording and transcription.
//

import Foundation
import Observation
import UIKit
import AVFoundation

/// ViewModel for RecordingView
@MainActor
@Observable
final class RecordingViewModel {
    
    // MARK: - Properties
    
    private let recordingService: RecordingService
    private let transcriptionService: TranscriptionService
    private let audioUploadService: AudioUploadService
    private let audioAPI: AudioAPI
    private let liveActivityService: LiveActivityService
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
    private var liveActivityTimer: Timer?
    private var recordingURL: URL?
    /// Transcript saved before pausing, to preserve when resuming
    private var savedTranscriptBeforePause: String = ""
    /// Task that observes AudioUploadService state for progress updates
    private var uploadObserveTask: Task<Void, Never>?
    /// Notification observer for stop recording from Live Activity
    /// Using nonisolated(unsafe) to allow cleanup in deinit
    nonisolated(unsafe) private var stopRecordingObserver: NSObjectProtocol?
    /// Callback triggered when recording is stopped from Live Activity
    var onStopFromLiveActivity: ((URL, String) -> Void)?
    
    private var isWhisperMode: Bool { audioAPI == .openaiWhisper }
    
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
        audioUploadService: AudioUploadService,
        audioAPI: AudioAPI,
        liveActivityService: LiveActivityService,
        session: Session? = nil
    ) {
        self.recordingService = recordingService
        self.transcriptionService = transcriptionService
        self.audioUploadService = audioUploadService
        self.audioAPI = audioAPI
        self.liveActivityService = liveActivityService
        self.session = session
        
        // Listen for stop recording notification from Live Activity
        setupNotificationObserver()
        
        Task {
            await checkPermissions()
        }
    }
    
    deinit {
        if let observer = stopRecordingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationObserver() {
        stopRecordingObserver = NotificationCenter.default.addObserver(
            forName: .stopRecordingFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleStopFromLiveActivity()
            }
        }
    }
    
    private func handleStopFromLiveActivity() async {
        guard canStop else { return }
        
        if let url = await stopRecording() {
            // Notify the view that recording was stopped from Live Activity
            onStopFromLiveActivity?(url, transcriptText)
        }
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() async {
        let micPermission = recordingService.hasPermission()
        if isWhisperMode {
            hasPermissions = micPermission
        } else {
            let speechPermission = await transcriptionService.hasPermission()
            hasPermissions = micPermission && speechPermission
        }
    }
    
    func requestPermissions() async {
        isRequestingPermissions = true
        
        let micGranted = await recordingService.requestPermission()
        if isWhisperMode {
            hasPermissions = micGranted
            isRequestingPermissions = false
            if !hasPermissions {
                showError(message: "Microphone permission is required to record.")
            }
        } else {
            let speechGranted = await transcriptionService.requestPermission()
            hasPermissions = micGranted && speechGranted
            isRequestingPermissions = false
            if !hasPermissions {
                showError(message: "Microphone and speech recognition permissions are required to record.")
            }
        }
    }
    
    // MARK: - Recording Actions
    
    func startRecording() async {
        guard canRecord else { return }
        
        do {
            recordingURL = try await recordingService.startRecording()
            recordingState = recordingService.state
            
            savedTranscriptBeforePause = ""
            
            startTimers()
            
            try? await liveActivityService.startActivity(sessionName: session?.title)
            
            if isWhisperMode {
                transcriptText = "Recording..."
            } else {
                Task {
                    await startLiveTranscription()
                }
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
            
            await liveActivityService.updateActivity(duration: duration, isPaused: true)
            
            if isWhisperMode {
                transcriptText = "Paused"
            } else {
                savedTranscriptBeforePause = transcriptText
                await transcriptionService.stopLiveTranscription()
            }
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
            
            await liveActivityService.updateActivity(duration: duration, isPaused: false)
            
            if isWhisperMode {
                transcriptText = "Recording..."
            } else {
                Task {
                    await startLiveTranscription()
                }
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    func stopRecording() async -> URL? {
        guard canStop else { return nil }
        
        stopTimers()
        await liveActivityService.endActivity()

        do {
            let url = try await recordingService.stopRecording()
            recordingState = .processing

            if isWhisperMode {
                await transcribeViaWhisper(url: url)
            } else {
                await transcriptionService.stopLiveTranscription()
                await transcribeRecording(url: url)
            }
            
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
        await liveActivityService.endActivity()
        
        if isWhisperMode {
            uploadObserveTask?.cancel()
            uploadObserveTask = nil
            await audioUploadService.cancel()
        } else {
            await transcriptionService.stopLiveTranscription()
        }
        
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
        print("📝 Starting file transcription for: \(url.path)")
        
        // Store the current live transcript as backup (this was working during recording)
        let liveTranscriptBackup = transcriptText
        print("📝 Live transcript backup: \(liveTranscriptBackup.count) characters")
        
        // Check audio file size for diagnostics
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
            print("📝 Audio file size: \(fileSize) bytes")
        }
        
        // Wait for app to be in foreground (needed when stopped from Live Activity)
        await waitForForeground()
        
        // Wait for audio system to settle
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        do {
            let fileTranscript = try await transcriptionService.transcribe(audioURL: url)
            let liveWordCount = liveTranscriptBackup.split(separator: " ").count
            let fileWordCount = fileTranscript.split(separator: " ").count
            print("📝 File transcription: \(fileWordCount) words, live backup: \(liveWordCount) words")
            
            // Keep whichever transcript captured more content
            if fileWordCount >= liveWordCount {
                transcriptText = fileTranscript
            } else {
                print("📝 Keeping live transcript (more words than file transcription)")
                transcriptText = liveTranscriptBackup
            }
        } catch {
            print("📝 File transcription failed: \(error)")
            
            if !liveTranscriptBackup.isEmpty {
                print("📝 Using live transcript as fallback (\(liveTranscriptBackup.count) characters)")
                transcriptText = liveTranscriptBackup
            } else {
                showError(message: "Transcription failed. You can edit the text manually.")
            }
        }
    }
    
    /// Uploads the recording to the backend via AudioUploadService for Whisper transcription.
    /// Observes upload state to show progress in the transcript text box.
    private func transcribeViaWhisper(url: URL) async {
        transcriptText = "Preparing audio..."
        
        // Observe upload state for real-time progress updates in the UI
        uploadObserveTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.audioUploadService.observeState()
            for await state in stream {
                guard !Task.isCancelled else { break }
                switch state {
                case .idle:
                    break
                case .preparing:
                    self.transcriptText = "Preparing audio..."
                case .uploading(let progress):
                    self.transcriptText = "Uploading audio... \(Int(progress * 100))%"
                case .processing:
                    self.transcriptText = "Transcribing audio..."
                case .completed:
                    break
                case .failed:
                    break
                }
            }
        }
        
        do {
            let transcript = try await audioUploadService.uploadInterviewAudio(
                fileURL: url,
                interviewId: session?.interviewId
            )
            transcriptText = transcript
        } catch {
            if (error as? AudioUploadError)?.isCancellation != true {
                showError(message: error.localizedDescription)
            }
            transcriptText = ""
        }
        
        uploadObserveTask?.cancel()
        uploadObserveTask = nil
    }
    
    /// Waits until the app is in the foreground (required for speech recognition from file)
    private func waitForForeground() async {
        // Check if already in foreground
        if UIApplication.shared.applicationState == .active {
            print("📝 App already in foreground")
            return
        }
        
        print("📝 Waiting for app to come to foreground...")
        
        // Wait for app to become active
        await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                print("📝 App is now in foreground")
                continuation.resume()
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
        
        // Live Activity timer (update every second)
        liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateLiveActivity()
            }
        }
    }
    
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
    }
    
    private func updateDuration() {
        duration = recordingService.duration
    }
    
    private func updateAudioLevel() {
        audioLevel = recordingService.getAudioLevel()
    }
    
    private func updateLiveActivity() async {
        guard isRecording else { return }
        await liveActivityService.updateActivity(duration: duration, isPaused: false)
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
