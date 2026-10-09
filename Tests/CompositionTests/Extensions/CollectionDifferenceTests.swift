// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CollectionDifferenceTests.swift
// dependencies: [Extensions/CollectionDifference.swift]

import Testing
@testable import Composition

@Suite struct CollectionDifferenceTests {

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
}
