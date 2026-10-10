// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/RangeReplaceableCollectionTests.swift
// dependencies: [Extensions/CollectionDifference.swift, Extensions/RangeReplaceableCollection.swift]

import Testing
@testable import Composition

private struct Box {

    let value: Int
}

@Suite struct RangeReplaceableCollectionTests {

    @Test func applyMatchesTarget() throws {
        var numbers: [Int] = [1, 2, 3, 4]
        let target: [Int] = [3, 1, 5, 4, 6]
        try numbers.apply(target.difference(from: numbers))
        #expect(numbers == target)
    }

    @Test func applyMatchesTargetWithoutRandomAccess() throws {
        var text: String = "kitten"
        try text.apply("sitting".difference(from: text))
        #expect(text == "sitting")
    }

    @Test func applySkipsElementCheckWithoutEquatable() throws {
        var boxes: [Box] = [Box(value: 1), Box(value: 2)]
        let difference: CollectionDifference<Box> = try #require(CollectionDifference([.remove(offset: 0, element: Box(value: 9), associatedWith: nil)]))
        try boxes.apply(difference)
        #expect(boxes.map(\.value) == [2])
    }

    @Test func applyThrowsOnElementMismatchAndLeavesCollectionUnchanged() {
        var numbers: [Int] = [1, 9, 3]
        #expect(throws: CollectionDifferenceError.elementMismatch(1)) { try numbers.apply([1, 3].difference(from: [1, 2, 3])) }
        #expect(numbers == [1, 9, 3])
    }

    @Test func applyThrowsOnInsertionOutOfBounds() throws {
        var numbers: [Int] = [1]
        let difference: CollectionDifference<Int> = try #require(CollectionDifference([.insert(offset: 3, element: 2, associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.offsetOutOfBounds(3)) { try numbers.apply(difference) }
        #expect(numbers == [1])
    }

    @Test func applyThrowsOnRemovalOutOfBounds() throws {
        var boxes: [Box] = [Box(value: 1)]
        let difference: CollectionDifference<Box> = try #require(CollectionDifference([.remove(offset: 1, element: Box(value: 1), associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.offsetOutOfBounds(1)) { try boxes.apply(difference) }
        #expect(boxes.count == 1)
    }
}
