//
//  RecordingActivityWidgetBundle.swift
//  RecordingActivityWidget
//
//  Widget bundle entry point for the recording Live Activity.
//

import WidgetKit
import SwiftUI

@main
struct RecordingActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}
