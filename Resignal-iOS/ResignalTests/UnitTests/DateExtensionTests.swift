//
//  DateExtensionTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Foundation
import Testing
@testable import Resignal

struct DateExtensionTests {

    @Test("relativeFormatted returns non-empty string")
    func relativeFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.relativeFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("relativeFormatted for past date")
    func relativeFormattedPastDate() async throws {
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let formatted = pastDate.relativeFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("shortFormatted returns non-empty string")
    func shortFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.shortFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("shortFormatted contains date components")
    func shortFormattedContainsComponents() async throws {
        let date = Date()
        let formatted = date.shortFormatted
        // Short format should contain separators like / or - or :
        let hasDateSeparator = formatted.contains("/") || formatted.contains("-") || formatted.contains(".")
        let hasTimeSeparator = formatted.contains(":")
        #expect(hasDateSeparator || hasTimeSeparator)
    }

    @Test("mediumFormatted returns non-empty string")
    func mediumFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.mediumFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("mediumFormatted is longer than shortFormatted")
    func mediumFormattedLongerThanShort() async throws {
        let date = Date()
        let short = date.shortFormatted
        let medium = date.mediumFormatted
        #expect(medium.count >= short.count)
    }
}

