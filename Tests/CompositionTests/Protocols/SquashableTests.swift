// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/SquashableTests.swift
// dependencies: [Protocols/Squashable.swift]

import Testing
@testable import Composition

private struct Log: Squashable, Equatable {

    let entries: [String]

    static let identity = Log(entries: [])

    func squashed(with next: Log) -> Log {
        Log(entries: entries + next.entries)
    }
}

@Suite struct SquashableTests {

    @Test func squashWithKeepsReceiverFirst() throws {
        var log = Log(entries: ["a"])
        try log.squash(with: Log(entries: ["b"]))
        #expect(log.entries == ["a", "b"])
    }

    @Test func squashedInOrderFoldsOldestFirst() throws {
        let logs = [Log(entries: ["a"]), Log(entries: ["b"]), Log(entries: ["c"])]
        #expect(try Log.squashed(inOrder: logs).entries == ["a", "b", "c"])
    }

    @Test func squashedInOrderOfNoChangesIsIdentity() throws {
        #expect(try Log.squashed(inOrder: [Log]()) == .identity)
    }
}
