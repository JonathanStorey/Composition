// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeStrategyTests.swift
// dependencies: [Protocols/MergeStrategy.swift]

import Testing
@testable import Composition

@Suite struct MergeStrategyTests {

    @Test func replaceKeepsTheSideThatChanged() throws {
        #expect(try ReplaceStrategy<String>().merged("draft", with: "base", from: "base") == "draft")
        #expect(try ReplaceStrategy<String>().merged("base", with: "final", from: "base") == "final")
    }

    @Test func replaceReturnsTheBaseWhenNeitherSideChanged() throws {
        #expect(try ReplaceStrategy<Int>().merged(0, with: 0, from: 0) == 0)
    }

    @Test func replaceThrowsWhenBothChangeDifferently() {
        #expect(throws: MergeStrategyError.conflict) { try ReplaceStrategy<Int>().merged(1, with: 2, from: 0) }
    }

    @Test func replaceWithDotSyntax() throws {
        #expect(try merged(5, with: 5, from: 0, using: .replace()) == 5)
    }

    private func merged<S: MergeStrategy>(_ ours: S.Value, with theirs: S.Value, from base: S.Value, using strategy: S) throws -> S.Value {
        try strategy.merged(ours, with: theirs, from: base)
    }
}
