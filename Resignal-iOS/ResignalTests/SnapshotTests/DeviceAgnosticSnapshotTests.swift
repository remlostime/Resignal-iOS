//
//  DeviceAgnosticSnapshotTests.swift
//  ResignalTests
//
//  Snapshot tests for different device configurations.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Resignal

final class DeviceAgnosticSnapshotTests: XCTestCase {

    func testEmptyStateView_iPhoneSE() {
        let view = EmptyStateView.noSessions
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)

        assertSnapshot(
            of: hostingController,
            as: .image(on: SnapshotDevice.iPhoneSE),
            record: isRecording
        )
    }

    func testEmptyStateView_iPhone15Pro() {
        let view = EmptyStateView.noSessions
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)

        assertSnapshot(
            of: hostingController,
            as: .image(on: SnapshotDevice.iPhone15Pro),
            record: isRecording
        )
    }

    func testEmptyStateView_iPadMini() {
        let view = EmptyStateView.noSessions
            .background(Color.white)

        let hostingController = UIHostingController(rootView: view)

        assertSnapshot(
            of: hostingController,
            as: .image(on: SnapshotDevice.iPadMini),
            record: isRecording
        )
    }
}

