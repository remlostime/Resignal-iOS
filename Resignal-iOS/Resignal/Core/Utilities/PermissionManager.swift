//
//  PermissionManager.swift
//  Resignal
//
//  Utility for managing app permissions.
//

import Foundation
import AVFoundation
import Speech
import Photos
import UIKit

/// Manager for handling various app permissions
@MainActor
final class PermissionManager {
    
    // MARK: - Microphone Permission
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    static func hasMicrophonePermission() -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied, .undetermined:
            return false
        @unknown default:
            return false
        }
    }
    
    static func microphonePermissionStatus() -> AVAudioSession.RecordPermission {
        AVAudioSession.sharedInstance().recordPermission
    }
    
    // MARK: - Speech Recognition Permission
    
    static func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    static func hasSpeechRecognitionPermission() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    static func speechRecognitionPermissionStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Photo Library Permission
    
    static func requestPhotoLibraryPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                Task { @MainActor in
                    let granted = status == .authorized || status == .limited
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    static func hasPhotoLibraryPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    static func photoLibraryPermissionStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    // MARK: - Combined Permissions
    
    static func requestAllRecordingPermissions() async -> (microphone: Bool, speech: Bool) {
        async let micGranted = requestMicrophonePermission()
        async let speechGranted = requestSpeechRecognitionPermission()
        
        return await (microphone: micGranted, speech: speechGranted)
    }
    
    static func hasAllRecordingPermissions() -> Bool {
        hasMicrophonePermission() && hasSpeechRecognitionPermission()
    }
    
    // MARK: - Settings Navigation
    
    static func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
