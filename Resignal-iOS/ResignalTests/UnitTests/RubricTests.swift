//
//  RubricTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

struct RubricTests {

    @Test("All rubrics have descriptions")
    func rubricDescriptions() async throws {
        for rubric in Rubric.allCases {
            #expect(!rubric.description.isEmpty)
            #expect(rubric.description == rubric.rawValue)
        }
    }

    @Test("Rubric count matches expected")
    func rubricCount() async throws {
        #expect(Rubric.allCases.count == 6)
    }
}

