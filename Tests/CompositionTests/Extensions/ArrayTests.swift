// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/ArrayTests.swift
// dependencies: [Extensions/Array.swift, Extensions/RangeReplaceableCollection.swift]

import Testing
@testable import Composition

@Suite struct ArrayTests {

    @Test func differenceFromBaseRoundTripsThroughApply() throws {
        let base: [String] = ["milk", "eggs", "bread"]
        let target: [String] = ["bread", "milk", "jam"]
        var list: [String] = base
        try list.apply(target.difference(from: base))
        #expect(list == target)
        #expect([String].Patch.self == CollectionDifference<String>.self)
    }

    @Test func differenceFromEmptyBaseInsertsEveryElement() throws {
        let target: [String] = ["milk", "eggs"]
        let patch: CollectionDifference<String> = target.difference(from: [])
        var list: [String] = []
        try list.apply(patch)
        #expect(patch.insertions.count == 2 && patch.removals.isEmpty)
        #expect(list == target)
    }
}
