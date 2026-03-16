//
//  ShakeDetector.swift
//  Resignal
//
//  Detects device shake gestures for triggering dev settings.
//  Uses a UIViewControllerRepresentable that becomes first responder,
//  ensuring motion events are delivered on real devices (not just simulator).
//  Only compiled in DEBUG builds.
//

#if DEBUG

import SwiftUI

// MARK: - View Modifier

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                ShakeDetectorRepresentable(action: action)
                    .frame(width: 0, height: 0)
            )
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(DeviceShakeViewModifier(action: action))
    }
}

// MARK: - UIKit Bridge

private struct ShakeDetectorRepresentable: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        ShakeDetectorViewController(onShake: action)
    }

    func updateUIViewController(_ controller: ShakeDetectorViewController, context: Context) {
        controller.onShake = action
    }
}

final class ShakeDetectorViewController: UIViewController {
    var onShake: () -> Void

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake()
    }
}

#endif
