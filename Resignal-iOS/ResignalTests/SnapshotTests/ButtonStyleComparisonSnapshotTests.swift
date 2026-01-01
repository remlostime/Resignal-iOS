//
//  ButtonStyleComparisonSnapshotTests.swift
//  ResignalTests
//
//  Snapshot tests for comparing all button styles.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Resignal

final class ButtonStyleComparisonSnapshotTests: XCTestCase {

    func testAllButtonStyles() {
        let view = VStack(spacing: 16) {
            PrimaryButton("Filled Button", icon: "sparkles") {}
            PrimaryButton("Outlined Button", icon: "square.and.pencil", style: .outlined) {}
            PrimaryButton("Text Button", icon: "doc.on.doc", style: .text) {}
            PrimaryButton("Disabled Button", isDisabled: true) {}
            DestructiveButton("Delete", icon: "trash") {}
        }
        .padding()
        .frame(width: 320)
        .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 360, height: 350)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }
}

