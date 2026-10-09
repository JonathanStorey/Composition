// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CollectionDifferenceTests.swift
// dependencies: [Extensions/CollectionDifference.swift, Extensions/RangeReplaceableCollection.swift, Protocols/Squashable.swift]

import Testing
@testable import Composition

@Suite struct CollectionDifferenceTests {

    @Test func adjustForPriorReplacesReceiver() throws {
        let base = ["milk", "eggs", "bread"]
        let mine = ["eggs", "bread"].difference(from: base)
        var partner = ["milk", "eggs"].difference(from: base)
        try partner.adjust(for: mine)
        var list = ["eggs", "bread"]
        try list.apply(partner)
        #expect(list == ["eggs"])
    }

    @Test func adjustedForPriorConvergesOnBothDevices() throws {
        let base = ["Intro", "Song A", "Song B", "Outro"]
        let mine = ["Bonus", "Intro", "Song B", "Outro"].difference(from: base)
        let partner = ["Intro", "Song A", "Outro", "Encore"].difference(from: base)
        var phone = ["Bonus", "Intro", "Song B", "Outro"]
        try phone.apply(partner.adjusted(for: mine))
        var laptop = ["Intro", "Song A", "Outro", "Encore"]
        try laptop.apply(mine.adjusted(for: partner))
        #expect(phone == ["Bonus", "Intro", "Outro", "Encore"])
        #expect(laptop == phone)
    }

    @Test func adjustedForPriorDropsRemovalThePriorAlreadyMade() throws {
        let base = ["milk", "eggs", "bread"]
        let removeEggs = ["milk", "bread"].difference(from: base)
        #expect(try removeEggs.adjusted(for: removeEggs).isEmpty)
    }

    @Test func adjustedForPriorPlacesPriorInsertionFirstOnTie() throws {
        let base = ["milk", "eggs"]
        let mine = ["milk", "eggs", "bread"].difference(from: base)
        let partner = ["milk", "eggs", "jam"].difference(from: base)
        var list = ["milk", "eggs", "bread"]
        try list.apply(partner.adjusted(for: mine))
        #expect(list == ["milk", "eggs", "bread", "jam"])
    }

    @Test func adjustedForPriorThrowsWhenBothRemoveDifferentElementsAtOneOffset() throws {
        let mine = try #require(CollectionDifference([.remove(offset: 1, element: "eggs", associatedWith: nil)]))
        let partner = try #require(CollectionDifference([.remove(offset: 1, element: "jam", associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.elementMismatch(1)) { try partner.adjusted(for: mine) }
    }

    @Test func associatedOffsetIsNilWithoutInferredMoves() {
        let difference = [2, 1].difference(from: [1, 2])
        #expect(!difference.isEmpty)
        #expect(difference.allSatisfy { $0.associatedOffset == nil })
    }

    @Test func associatedOffsetPairsInferredMoves() {
        let difference = [2, 1].difference(from: [1, 2]).inferringMoves()
        #expect(!difference.isEmpty)
        for change in difference {
            let partners = change.isInsertion ? difference.removals : difference.insertions
            let partner = partners.first(where: { $0.offset == change.associatedOffset })
            #expect(partner?.associatedOffset == change.offset)
            #expect(partner?.element == change.element)
        }
    }

    @Test func changeAccessorsReadInsertionsAndRemovals() throws {
        let difference = [1, 3].difference(from: [1, 2])
        let removal = try #require(difference.removals.first)
        let insertion = try #require(difference.insertions.first)
        #expect(removal.isRemoval && !removal.isInsertion)
        #expect(removal.offset == 1 && removal.element == 2)
        #expect(insertion.isInsertion && !insertion.isRemoval)
        #expect(insertion.offset == 1 && insertion.element == 3)
    }

    @Test func mergeWithReplacesReceiver() throws {
        let base = ["milk", "eggs"]
        var mine = ["eggs"].difference(from: base)
        try mine.merge(with: ["milk", "eggs", "jam"].difference(from: base))
        var list = base
        try list.apply(mine)
        #expect(list == ["eggs", "jam"])
    }

    @Test func mergedWithMatchesEachDeviceAfterAdjusting() throws {
        let base = ["Intro", "Song A", "Song B", "Outro"]
        let mine = ["Bonus", "Intro", "Song B", "Outro"].difference(from: base)
        let partner = ["Intro", "Song A", "Outro", "Encore"].difference(from: base)
        var list = base
        try list.apply(mine.merged(with: partner))
        #expect(list == ["Bonus", "Intro", "Outro", "Encore"])
    }

    @Test func mergedWithPlacesReceiverInsertionFirstOnTie() throws {
        let base = ["milk", "eggs"]
        let mine = ["milk", "eggs", "bread"].difference(from: base)
        let partner = ["milk", "eggs", "jam"].difference(from: base)
        var list = base
        try list.apply(mine.merged(with: partner))
        #expect(list == ["milk", "eggs", "bread", "jam"])
    }

    @Test func squashedWithCancelsInsertionThatNextRemoves() throws {
        let difference = try [1, 9, 2].difference(from: [1, 2]).squashed(with: [1, 2].difference(from: [1, 9, 2]))
        #expect(difference.isEmpty)
    }

    @Test func squashedWithMatchesApplyingBothInOrder() throws {
        let words = ["kitten", "sitting", "mitten", "", "smitten", "knit", "kit"]
        for base in words {
            for middle in words {
                for target in words {
                    var text = base
                    try text.apply(middle.difference(from: base).squashed(with: target.difference(from: middle)))
                    #expect(text == target)
                }
            }
        }
    }

    @Test func squashedWithThrowsWhenNextRemovesDifferentInsertedElement() throws {
        let first = [1, 9].difference(from: [1])
        let next = try #require(CollectionDifference([.remove(offset: 1, element: 7, associatedWith: nil)]))
        #expect(throws: CollectionDifferenceError.elementMismatch(1)) { try first.squashed(with: next) }
    }
}
