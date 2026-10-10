// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategyTests.swift
// dependencies: [Extensions/CollectionDifference.swift, Protocols/DiffableMergeStrategy.swift, Protocols/MergeStrategy.swift]

import Testing
@testable import Composition

@Suite struct DiffableMergeStrategyTests {

    @Test func applyingThrowsWhenTheDifferenceDoesNotFit() {
        let strategy: ArrayStrategy = ArrayStrategy()
        #expect(throws: MergeStrategyError.conflict) { try strategy.applying(strategy.difference(from: [1, 2, 3], to: []), to: []) }
    }

    @Test func mergedCombinesTheDifferencesOfBothSides() throws {
        #expect(try ArrayStrategy().merged([0, 1, 2, 3], with: [1, 2, 3, 4], from: [1, 2, 3]) == [0, 1, 2, 3, 4])
    }

    @Test func mergedReturnsTheBaseWhenNeitherSideChanged() throws {
        #expect(try ArrayStrategy().merged([1, 2, 3], with: [1, 2, 3], from: [1, 2, 3]) == [1, 2, 3])
    }

    @Test func roundTripsTheDifference() throws {
        let strategy: ArrayStrategy = ArrayStrategy()
        #expect(try strategy.applying(strategy.difference(from: [1, 2, 3], to: [3, 1]), to: [1, 2, 3]) == [3, 1])
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private struct ArrayStrategy: DiffableMergeStrategy {

    func applying(_ difference: CollectionDifference<Int>, to value: [Int]) throws -> [Int] {
        guard let result: [Int] = value.applying(difference) else { throw MergeStrategyError.conflict }
        return result
    }

    func difference(from original: [Int], to updated: [Int]) -> CollectionDifference<Int> {
        updated.difference(from: original)
    }
}
