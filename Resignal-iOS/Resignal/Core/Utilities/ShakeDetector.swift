//
//  ShakeDetector.swift
//  Resignal
//
//  Detects device shake gestures for triggering dev settings.
//  Only compiled in DEBUG builds.
//

#if DEBUG

import UIKit

// MARK: - Shake Notification

extension UIDevice {
    /// Notification posted when a device shake gesture is detected.
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")
}

// MARK: - UIWindow Extension

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

#endif
