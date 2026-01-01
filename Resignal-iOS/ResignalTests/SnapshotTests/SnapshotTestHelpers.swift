//
//  SnapshotTestHelpers.swift
//  ResignalTests
//
//  Shared configuration for snapshot tests.
//

import SnapshotTesting

// MARK: - Snapshot Test Configuration

/// Set to true to record new reference snapshots
let isRecording = false

/// Common device configurations for testing
enum SnapshotDevice {
    static let iPhoneSE = ViewImageConfig.iPhoneSe
    static let iPhone15Pro = ViewImageConfig.iPhone13Pro
    static let iPadMini = ViewImageConfig.iPadMini
}

