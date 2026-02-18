//
//  RecordingServiceImpl.swift
//  Resignal
//
//  Implementation of audio recording using AVAudioRecorder.
//

import Foundation
import AVFoundation

/// Implementation of RecordingService using AVAudioRecorder
@MainActor
final class RecordingServiceImpl: NSObject, RecordingService {
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var levelTimer: Timer?
    
    private(set) var state: RecordingState = .idle
    private(set) var duration: TimeInterval = 0
    
    // MARK: - RecordingService Implementation
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func hasPermission() -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied, .undetermined:
            return false
        @unknown default:
            return false
        }
    }
    
    func startRecording() async throws -> URL {
        guard state == .idle else {
            throw RecordingError.alreadyRecording
        }
        
        guard hasPermission() else {
            throw RecordingError.permissionDenied
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            throw RecordingError.audioSessionFailed
        }
        
        // Create recording URL
        let fileURL = createRecordingFileURL()
        recordingURL = fileURL
        
        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create and start recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.record() == true else {
                throw RecordingError.recordingFailed
            }
            
            state = .recording
            startTime = Date()
            pausedDuration = 0
            startLevelMonitoring()
            
            return fileURL
        } catch {
            throw RecordingError.recordingFailed
        }
    }
    
    func stopRecording() async throws -> URL {
        guard state == .recording || state == .paused else {
            throw RecordingError.notRecording
        }
        
        state = .processing
        stopLevelMonitoring()
        
        audioRecorder?.stop()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // Non-fatal error
        }
        
        guard let url = recordingURL else {
            throw RecordingError.fileOperationFailed
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingError.fileOperationFailed
        }
        
        state = .idle
        audioRecorder = nil
        recordingURL = nil
        startTime = nil
        pausedDuration = 0
        
        return url
    }
    
    func pauseRecording() throws {
        guard state == .recording else {
            throw RecordingError.notRecording
        }
        
        audioRecorder?.pause()
        state = .paused
        
        if let startTime = startTime {
            pausedDuration += Date().timeIntervalSince(startTime)
        }
        
        stopLevelMonitoring()
    }
    
    func resumeRecording() throws {
        guard state == .paused else {
            throw RecordingError.notRecording
        }
        
        audioRecorder?.record()
        state = .recording
        startTime = Date()
        startLevelMonitoring()
    }
    
    func cancelRecording() async throws {
        stopLevelMonitoring()
        
        audioRecorder?.stop()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // Non-fatal error
        }
        
        // Delete the recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        state = .idle
        audioRecorder = nil
        recordingURL = nil
        startTime = nil
        pausedDuration = 0
    }
    
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, state == .recording else {
            return 0.0
        }
        
        recorder.updateMeters()
        let avgPower = recorder.averagePower(forChannel: 0)
        
        // Convert dB to 0.0-1.0 range
        // avgPower ranges from -160 (silence) to 0 (max)
        let normalized = (avgPower + 160) / 160
        return max(0.0, min(1.0, normalized))
    }
    
    // MARK: - Private Helpers
    
    private func createRecordingFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsFolder = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create recordings folder if it doesn't exist
        try? FileManager.default.createDirectory(at: recordingsFolder, withIntermediateDirectories: true)
        
        let filename = "recording_\(UUID().uuidString).m4a"
        return recordingsFolder.appendingPathComponent(filename)
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDuration()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateDuration() {
        guard state == .recording, let startTime = startTime else {
            return
        }
        duration = pausedDuration + Date().timeIntervalSince(startTime)
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingServiceImpl: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Handle recording completion if needed
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        // Handle encoding errors if needed
    }
}

// MARK: - Mock Implementation

@MainActor
final class MockRecordingService: RecordingService {
    var state: RecordingState = .idle
    var duration: TimeInterval = 0
    var shouldGrantPermission = true
    var shouldFailRecording = false
    
    func requestPermission() async -> Bool {
        return shouldGrantPermission
    }
    
    func hasPermission() -> Bool {
        return shouldGrantPermission
    }
    
    func startRecording() async throws -> URL {
        guard !shouldFailRecording else {
            throw RecordingError.recordingFailed
        }
        state = .recording
        return URL(fileURLWithPath: "/tmp/mock_recording.m4a")
    }
    
    func stopRecording() async throws -> URL {
        state = .idle
        return URL(fileURLWithPath: "/tmp/mock_recording.m4a")
    }
    
    func pauseRecording() throws {
        state = .paused
    }
    
    func resumeRecording() throws {
        state = .recording
    }
    
    func cancelRecording() async throws {
        state = .idle
    }
    
    func getAudioLevel() -> Float {
        return state == .recording ? 0.5 : 0.0
    }
}
