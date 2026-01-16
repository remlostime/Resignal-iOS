//
//  ResignalTests.swift
//  Resignal
//
//  Created by Kai Chen on 1/15/26.
//

import Testing

struct RouterTests {
    @Test("example")
    func alwaysPasses() {
        #expect(1 + 1 == 2)
    }
}
