//
//  UIComponentSnapshotTests.swift
//  ResignalTests
//
//  Snapshot tests for UI components.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Resignal

final class UIComponentSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Uncomment to record new snapshots:
    }

    // MARK: - PrimaryButton Tests

    func testPrimaryButton_Filled() {
        let view = PrimaryButton("Analyze", icon: "sparkles") {}
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 80)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testPrimaryButton_Outlined() {
        let view = PrimaryButton("Cancel", style: .outlined) {}
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 80)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testPrimaryButton_Text() {
        let view = PrimaryButton("Copy", icon: "doc.on.doc", style: .text) {}
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 150, height: 60)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testPrimaryButton_Loading() {
        let view = PrimaryButton("Analyzing...", isLoading: true) {}
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 80)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testPrimaryButton_Disabled() {
        let view = PrimaryButton("Disabled", isDisabled: true) {}
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 80)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    // MARK: - EmptyStateView Tests

    func testEmptyStateView_NoSessions() {
        let view = EmptyStateView.noSessions
            .frame(width: 350, height: 350)
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 350)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testEmptyStateView_WithAction() {
        let view = EmptyStateView(
            icon: "plus.circle",
            title: "Create Your First Session",
            description: "Tap the button below to start",
            actionTitle: "New Session"
        ) {}
            .frame(width: 350, height: 400)
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 400)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testEmptyStateView_PendingAnalysis() {
        let view = EmptyStateView.pendingAnalysis
            .frame(width: 350, height: 350)
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 350)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    // MARK: - TagChipsView Tests

    func testTagChipsView_SingleTag() {
        let view = TagChipsView(tags: ["iOS"])
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 200, height: 60)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testTagChipsView_MultipleTags() {
        let view = TagChipsView(tags: ["iOS", "Swift", "SwiftUI", "Technical"])
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 100)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testTagChipsView_WithRemoveButton() {
        let view = TagChipsView(tags: ["iOS", "Swift", "SwiftUI"]) { _ in }
            .frame(width: 300)
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 340, height: 100)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    // MARK: - SectionCard Tests

    func testSectionCard_Basic() {
        let view = SectionCard(title: "Summary", icon: "doc.text") {
            Text("This is the content of the section card.")
                .foregroundStyle(Color.gray)
        }
        .frame(width: 350)
        .padding()
        .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 200)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testSectionCard_Expandable() {
        let view = SectionCard(title: "Details", icon: "info.circle", isExpandable: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("• First item")
                Text("• Second item")
                Text("• Third item")
            }
            .foregroundStyle(Color.gray)
        }
        .frame(width: 350)
        .padding()
        .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 250)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    // MARK: - FeedbackSectionView Tests

    func testFeedbackSectionView_Expanded() {
        let view = FeedbackSectionView(
            title: "Strengths",
            icon: "star.fill",
            content: "- Good communication skills\n- Clear explanations\n- Technical depth",
            isExpanded: .constant(true)
        )
        .frame(width: 350)
        .padding()
        .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 250)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    func testFeedbackSectionView_Collapsed() {
        let view = FeedbackSectionView(
            title: "Weaknesses",
            icon: "exclamationmark.triangle",
            content: "Some content here",
            isExpanded: .constant(false)
        )
        .frame(width: 350)
        .padding()
        .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 380, height: 100)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }

    // MARK: - DestructiveButton Tests

    func testDestructiveButton() {
        let view = DestructiveButton("Delete", icon: "trash") {}
            .padding()
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 150, height: 60)

        assertSnapshot(of: hostingController, as: .image, record: isRecording)
    }
}

