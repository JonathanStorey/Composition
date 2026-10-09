// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeableTests.swift
// dependencies: [Protocols/Mergeable.swift, Protocols/Squashable.swift]

import Testing
@testable import Composition

private struct EmptyLog: Error {}

private struct Log: Mergeable {

    let entries: [String]

    func adjusted(for prior: Log) throws -> Log {
        guard !entries.isEmpty else { throw EmptyLog() }
        return Log(entries: entries.map { "\($0) after \(prior.entries.joined())" })
    }

    func squashed(with next: Log) throws -> Log {
        Log(entries: entries + next.entries)
    }
}

@Suite struct MergeableTests {

    @Test func mergeWithLeavesReceiverUnchangedWhenAdjustingThrows() {
        var log = Log(entries: ["a"])
        #expect(throws: EmptyLog.self) { try log.merge(with: Log(entries: [])) }
        #expect(log.entries == ["a"])
    }

    @Test func mergeWithReplacesReceiver() throws {
        var log = Log(entries: ["a"])
        try log.merge(with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b after a"])
    }

    @Test func mergedWithAdjustsOtherForReceiver() throws {
        let log = try Log(entries: ["a"]).merged(with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b after a"])
    }

    @Test func staticMergedAdjustsOtherForFirst() throws {
        let log = try Log.merged(Log(entries: ["a"]), with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b after a"])
    }
}
