// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeableTests.swift
// dependencies: [Protocols/Mergeable.swift, Protocols/Shiftable.swift, Protocols/Squashable.swift]

import Testing
@testable import Composition

private struct EmptyLog: Error {}

private struct Log: Mergeable, Shiftable, Squashable {

    let entries: [String]

    func shifted(by prior: Log) throws -> Log {
        guard !entries.isEmpty else { throw EmptyLog() }
        return Log(entries: entries.map { "\($0) after \(prior.entries.joined())" })
    }

    func squashed(with next: Log) throws -> Log {
        Log(entries: entries + next.entries)
    }
}

private struct Tags: Mergeable {

    let names: Set<String>

    func merged(with other: Tags) -> Tags {
        Tags(names: names.union(other.names))
    }
}

@Suite struct MergeableTests {

    @Test func mergeWithLeavesReceiverUnchangedWhenMergingThrows() {
        var log: Log = Log(entries: ["a"])
        #expect(throws: EmptyLog.self) { try log.merge(with: Log(entries: [])) }
        #expect(log.entries == ["a"])
    }

    @Test func mergeWithReplacesReceiver() throws {
        var tags: Tags = Tags(names: ["swift"])
        try tags.merge(with: Tags(names: ["ios"]))
        #expect(tags.names == ["ios", "swift"])
    }

    @Test func mergedWithDefaultsToSquashingTheOtherShiftedPastReceiver() throws {
        let log: Log = try Log(entries: ["a"]).merged(with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b after a"])
    }

    @Test func mergedWithUsesConformersOwnImplementation() {
        #expect(Tags(names: ["swift"]).merged(with: Tags(names: ["swift", "ios"])).names == ["ios", "swift"])
    }

    @Test func staticMergedKeepsFirstAsReceiver() throws {
        let log: Log = try Log.merged(Log(entries: ["a"]), with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b after a"])
    }
}
