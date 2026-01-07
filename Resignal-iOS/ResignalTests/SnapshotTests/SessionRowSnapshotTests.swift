//
//  SessionRowSnapshotTests.swift
//  ResignalTests
//
//  Snapshot tests for SessionRowView.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Resignal

@MainActor
final class SessionRowSnapshotTests: XCTestCase {

    func testSessionRowView_WithAnalysis() {
        let session = Session(
            title: "iOS Engineer Interview",
            role: "Senior iOS Developer",
            inputText: "Q: Tell me about your experience with SwiftUI.\nA: I have been working with SwiftUI since its introduction...",
            outputFeedback: "Some feedback",
            rubric: .softwareEngineering,
            tags: ["iOS", "Swift", "Technical"]
        )

        let view = SessionRowView(session: session)
            .frame(width: 350)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 180)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testSessionRowView_WithoutAnalysis() {
        let session = Session(
            title: "Draft Session",
            inputText: "Q: What is your greatest strength?\nA: Problem solving..."
        )

        let view = SessionRowView(session: session)
            .frame(width: 350)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 150)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testSessionRowView_LongTitle() {
        let session = Session(
            title: "This is a very long session title that should be truncated properly",
            inputText: "Some input text here",
            outputFeedback: "Feedback",
            tags: ["Tag1", "Tag2", "Tag3", "Tag4"]
        )

        let view = SessionRowView(session: session)
            .frame(width: 350)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 180)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }
}



