// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CollectionDifferenceTests.swift
// dependencies: [Extensions/CollectionDifference.swift, Extensions/RangeReplaceableCollection.swift, Protocols/Mergeable.swift, Protocols/Shiftable.swift, Protocols/Squashable.swift]

import Testing
@testable import Composition

@Suite struct CollectionDifferenceTests {

    @Test func associatedOffsetIsNilWithoutInferredMoves() {
        let difference: CollectionDifference<Int> = [2, 1].difference(from: [1, 2])
        #expect(!difference.isEmpty)
        #expect(difference.allSatisfy { $0.associatedOffset == nil })
    }

    @Test func associatedOffsetPairsInferredMoves() {
        let difference: CollectionDifference<Int> = [2, 1].difference(from: [1, 2]).inferringMoves()
        #expect(!difference.isEmpty)
        for change in difference {
            let partners: [CollectionDifference<Int>.Change] = change.isInsertion ? difference.removals : difference.insertions
            let partner: CollectionDifference<Int>.Change? = partners.first(where: { $0.offset == change.associatedOffset })
            #expect(partner?.associatedOffset == change.offset)
            #expect(partner?.element == change.element)
        }
    }

    @Test func changeAccessorsReadInsertionsAndRemovals() throws {
        let difference: CollectionDifference<Int> = [1, 3].difference(from: [1, 2])
        let removal: CollectionDifference<Int>.Change = try #require(difference.removals.first)
        let insertion: CollectionDifference<Int>.Change = try #require(difference.insertions.first)
        #expect(removal.isRemoval && !removal.isInsertion)
        #expect(removal.offset == 1 && removal.element == 2)
        #expect(insertion.isInsertion && !insertion.isRemoval)
        #expect(insertion.offset == 1 && insertion.element == 3)
    }

    @Test func changesIsEmptyWithoutDifferences() {
        let difference: CollectionDifference<Int> = [1, 2].difference(from: [1, 2])
        #expect(difference.changes.isEmpty)
    }

    @Test func changesListsEveryRemovalAndInsertion() {
        let difference: CollectionDifference<Int> = [1, 3].difference(from: [1, 2])
        #expect(difference.changes.count == 2)
        #expect(difference.changes == Array(difference))
    }

    @Test func mergeWithReplacesReceiver() throws {
        let base: [String] = ["milk", "eggs"]
        var mine: CollectionDifference<String> = ["eggs"].difference(from: base)
        try mine.merge(with: ["milk", "eggs", "jam"].difference(from: base))
        var list: [String] = base
        try list.apply(mine)
        #expect(list == ["eggs", "jam"])
    }

    @Test func mergedWithMatchesEachDeviceAfterShifting() throws {
        let base: [String] = ["Intro", "Song A", "Song B", "Outro"]
        let mine: CollectionDifference<String> = ["Bonus", "Intro", "Song B", "Outro"].difference(from: base)
        let partner: CollectionDifference<String> = ["Intro", "Song A", "Outro", "Encore"].difference(from: base)
        var list: [String] = base
        try list.apply(mine.merged(with: partner))
        #expect(list == ["Bonus", "Intro", "Outro", "Encore"])
    }

    @Test func mergedWithPlacesReceiverInsertionFirstOnTie() throws {
        let base: [String] = ["milk", "eggs"]
        let mine: CollectionDifference<String> = ["milk", "eggs", "bread"].difference(from: base)
        let partner: CollectionDifference<String> = ["milk", "eggs", "jam"].difference(from: base)
        var list: [String] = base
        try list.apply(mine.merged(with: partner))
        #expect(list == ["milk", "eggs", "bread", "jam"])
    }

    @Test func shiftedByPriorConvergesOnBothDevices() throws {
        let base: [String] = ["Intro", "Song A", "Song B", "Outro"]
        let mine: CollectionDifference<String> = ["Bonus", "Intro", "Song B", "Outro"].difference(from: base)
        let partner: CollectionDifference<String> = ["Intro", "Song A", "Outro", "Encore"].difference(from: base)
        var phone: [String] = ["Bonus", "Intro", "Song B", "Outro"]
        try phone.apply(partner.shifted(by: mine))
        var laptop: [String] = ["Intro", "Song A", "Outro", "Encore"]
        try laptop.apply(mine.shifted(by: partner))
        #expect(phone == ["Bonus", "Intro", "Outro", "Encore"])
        #expect(laptop == phone)
    }

    @Test func shiftedByPriorDropsRemovalThePriorAlreadyMade() throws {
        let base: [String] = ["milk", "eggs", "bread"]
        let removeEggs: CollectionDifference<String> = ["milk", "bread"].difference(from: base)
        #expect(try removeEggs.shifted(by: removeEggs).isEmpty)
    }

    @Test func shiftedByPriorPlacesPriorInsertionFirstOnTie() throws {
        let base: [String] = ["milk", "eggs"]
        let mine: CollectionDifference<String> = ["milk", "eggs", "bread"].difference(from: base)
        let partner: CollectionDifference<String> = ["milk", "eggs", "jam"].difference(from: base)
        var list: [String] = ["milk", "eggs", "bread"]
        try list.apply(partner.shifted(by: mine))
        #expect(list == ["milk", "eggs", "bread", "jam"])
    }

    @Test func shiftedByPriorThrowsWhenBothRemoveDifferentElementsAtOneOffset() throws {
        let mine: CollectionDifference<String> = try #require(CollectionDifference([.remove(offset: 1, element: "eggs", associatedWith: nil)]))
        let partner: CollectionDifference<String> = try #require(CollectionDifference([.remove(offset: 1, element: "jam", associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.elementMismatch(1)) { try partner.shifted(by: mine) }
    }

    @Test func squashedWithCancelsInsertionThatNextRemoves() throws {
        let difference: CollectionDifference<Int> = try [1, 9, 2].difference(from: [1, 2]).squashed(with: [1, 2].difference(from: [1, 9, 2]))
        #expect(difference.isEmpty)
    }

    @Test func squashedWithMatchesApplyingBothInOrder() throws {
        let words: [String] = ["kitten", "sitting", "mitten", "", "smitten", "knit", "kit"]
        for base in words {
            for middle in words {
                for target in words {
                    var text: String = base
                    try text.apply(middle.difference(from: base).squashed(with: target.difference(from: middle)))
                    #expect(text == target)
                }
            }
        }
    }

    @Test func squashedWithThrowsWhenNextRemovesDifferentInsertedElement() throws {
        let first: CollectionDifference<Int> = [1, 9].difference(from: [1])
        let next: CollectionDifference<Int> = try #require(CollectionDifference([.remove(offset: 1, element: 7, associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.elementMismatch(1)) { try first.squashed(with: next) }
    }
}
