// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/ShiftableTests.swift
// dependencies: [Protocols/Shiftable.swift]

import Testing
@testable import Composition

private struct NegativeShift: Error {}

private struct Insertion: Shiftable {

    let offset: Int

    func shifted(by prior: Insertion) throws -> Insertion {
        guard prior.offset >= 0 else { throw NegativeShift() }
        return prior.offset <= offset ? Insertion(offset: offset + 1) : self
    }
}

@Suite struct ShiftableTests {

    @Test func shiftByPriorLeavesReceiverUnchangedWhenShiftingThrows() {
        var insertion = Insertion(offset: 3)
        #expect(throws: NegativeShift.self) { try insertion.shift(by: Insertion(offset: -1)) }
        #expect(insertion.offset == 3)
    }

    @Test func shiftByPriorReplacesReceiver() throws {
        var insertion = Insertion(offset: 3)
        try insertion.shift(by: Insertion(offset: 1))
        #expect(insertion.offset == 4)
    }
}
