// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategyTests.swift
// dependencies: [Extensions/CollectionDifference.swift, Protocols/DiffableMergeStrategy.swift, Protocols/MergeStrategy.swift]

import Testing
@testable import Composition

@Suite struct DiffableMergeStrategyTests {

    @Test func listApplyingThrowsWhenTheDifferenceDoesNotFit() {
        let strategy: ListStrategy<[Int]> = ListStrategy()
        #expect(throws: CollectionDifferenceError.self) { try strategy.applying(strategy.difference(from: [1, 2, 3], to: []), to: []) }
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

    private func merged<S: MergeStrategy>(_ ours: S.Value, with theirs: S.Value, from base: S.Value, using strategy: S) throws -> S.Value {
        try strategy.merged(ours, with: theirs, from: base)
    }
}
