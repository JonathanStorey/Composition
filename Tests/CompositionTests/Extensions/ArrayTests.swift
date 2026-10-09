// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/ArrayTests.swift
// dependencies: [Extensions/Array.swift, Extensions/RangeReplaceableCollection.swift]

import Testing
@testable import Composition

@Suite struct ArrayTests {

    @Test func differenceFromBaseRoundTripsThroughApply() throws {
        let base = ["milk", "eggs", "bread"]
        let target = ["bread", "milk", "jam"]
        var list = base
        try list.apply(target.difference(from: base))
        #expect(list == target)
        #expect([String].Patch.self == CollectionDifference<String>.self)
    }

    @Test func differenceFromEmptyBaseInsertsEveryElement() throws {
        let target = ["milk", "eggs"]
        let patch = target.difference(from: [])
        var list: [String] = []
        try list.apply(patch)
        #expect(patch.insertions.count == 2 && patch.removals.isEmpty)
        #expect(list == target)
    }
}
