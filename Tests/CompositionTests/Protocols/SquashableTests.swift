// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/SquashableTests.swift
// dependencies: [Protocols/Squashable.swift]

import Testing
@testable import Composition

private struct EmptyLog: Error {}

private struct Log: Squashable {

    let entries: [String]

    func squashed(with next: Log) throws -> Log {
        guard !next.entries.isEmpty else { throw EmptyLog() }
        return Log(entries: entries + next.entries)
    }
}

@Suite struct SquashableTests {

    @Test func squashWithKeepsReceiverFirst() throws {
        var log: Log = Log(entries: ["a"])
        try log.squash(with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b"])
    }

    @Test func squashWithLeavesReceiverUnchangedWhenSquashingThrows() {
        var log: Log = Log(entries: ["a"])
        #expect(throws: EmptyLog.self) { try log.squash(with: Log(entries: [])) }
        #expect(log.entries == ["a"])
    }

    @Test func staticSquashedKeepsFirstBeforeNext() throws {
        let log: Log = try Log.squashed(Log(entries: ["a"]), with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b"])
    }
}
