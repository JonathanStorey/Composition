// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategyTests.swift
// dependencies: [Protocols/DiffableMergeStrategy.swift, Protocols/MergeStrategy.swift]

import Testing
@testable import Composition

@Suite struct DiffableMergeStrategyTests {

    @Test func listApplyingThrowsWhenTheDifferenceDoesNotFit() {
        let strategy: ListStrategy<[Int]> = ListStrategy()
        #expect(throws: MergeStrategyError.conflict) { try strategy.applying(strategy.difference(from: [1, 2, 3], to: []), to: []) }
    }

    @Test func listKeepsInsertionsFromBothSides() {
        #expect(ListStrategy<[Int]>().merged([0, 1, 2, 3], with: [1, 2, 3, 4], from: [1, 2, 3]) == [0, 1, 2, 3, 4])
    }

    @Test func listMergesStrings() {
        #expect(ListStrategy<String>().merged("cats", with: "bat", from: "cat") == "bats")
    }

    @Test func listRemovesElementBothSidesRemovedOnce() {
        #expect(ListStrategy<[Int]>().merged([1, 3], with: [1, 9, 3], from: [1, 2, 3]) == [1, 9, 3])
    }

    @Test func listRoundTripsTheDifference() throws {
        let strategy: ListStrategy<String> = ListStrategy()
        #expect(try strategy.applying(strategy.difference(from: "cat", to: "bats"), to: "cat") == "bats")
    }

    @Test func listWithDotSyntax() throws {
        #expect(try merged([0, 1, 2, 3], with: [1, 2, 3, 4], from: [1, 2, 3], using: .list()) == [0, 1, 2, 3, 4])
    }

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

    @Test func replacementMergesWithAnUnchangedReplacement() throws {
        #expect(try Replacement(1).merged(with: Replacement()) == Replacement(1))
        #expect(try Replacement().merged(with: Replacement(1)) == Replacement(1))
    }

    @Test func replacementThrowsWhenBothSetDifferentValues() {
        #expect(throws: MergeStrategyError.conflict) { try Replacement(1).merged(with: Replacement(2)) }
    }

    private func merged<S: MergeStrategy>(_ ours: S.Value, with theirs: S.Value, from base: S.Value, using strategy: S) throws -> S.Value {
        try strategy.merged(ours, with: theirs, from: base)
    }
}
