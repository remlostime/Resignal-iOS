//
//  AccessibilitySnapshotTests.swift
//  ResignalTests
//
//  Snapshot tests for accessibility hierarchy descriptions.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Resignal

final class AccessibilitySnapshotTests: XCTestCase {

    func testPrimaryButton_HierarchyDescription() {
        let view = PrimaryButton("Analyze", icon: "sparkles") {}
            .frame(width: 300)
            .padding()

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 80)

        assertSnapshot(of: hostingController, as: .recursiveDescription, record: isRecording)
    }

    func testEmptyStateView_HierarchyDescription() {
        let view = EmptyStateView.noSessions
            .frame(width: 350, height: 350)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 350)

        assertSnapshot(of: hostingController, as: .recursiveDescription, record: isRecording)
    }

    func testTagChipsView_HierarchyDescription() {
        let view = TagChipsView(tags: ["iOS", "Swift", "SwiftUI"])
            .frame(width: 300)
            .padding()

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 100)

        assertSnapshot(of: hostingController, as: .recursiveDescription, record: isRecording)
    }
}

