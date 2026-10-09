// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/PermutableCollectionTests.swift
// dependencies: [Protocols/PermutableCollection.swift, Protocols/Squashable.swift]

import Testing
@testable import Composition

private struct SeededGenerator: RandomNumberGenerator {

    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private struct Deck: PermutableCollection {

    var cards: [String]

    var endIndex: Int { cards.endIndex }

    var startIndex: Int { cards.startIndex }

    subscript(position: Int) -> String { cards[position] }

    func index(after i: Int) -> Int {
        cards.index(after: i)
    }

    mutating func swapAt(_ i: Int, _ j: Int) {
        cards.swapAt(i, j)
    }
}

private struct Hand: PermutableCollection, RandomAccessCollection {

    var cards: [String]

    var endIndex: Int { cards.endIndex }

    var startIndex: Int { cards.startIndex }

    subscript(position: Int) -> String { cards[position] }

    mutating func swapAt(_ i: Int, _ j: Int) {
        cards.swapAt(i, j)
    }
}

@Suite struct PermutableCollectionTests {

    @Test func invertedOfEmptyPermutationIsEmpty() {
        #expect(Permutation(shuffles: 0).inverted.cycle.isEmpty)
    }

    @Test func invertedUndoesShuffle() {
        let original = (0..<25).map(String.init)
        var deck = Deck(cards: original)
        let permutation = deck.shuffle()
        deck.permute(using: permutation.inverted)
        #expect(deck.cards == original)
    }

    @Test func minimumCountIsOneMoreThanLargestOffset() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        #expect(deck.reverse().minimumCount == 5)
        #expect(deck.rotate(toStartAt: 1).minimumCount == 5)
    }

    @Test func minimumCountOfEmptyPermutationIsZero() {
        #expect(Permutation(shuffles: 0).minimumCount == 0)
    }

    @Test func moveFromOffsetsToEndKeepsRelativeOrder() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.move(fromOffsets: [3, 1], toOffset: 5)
        #expect(deck.cards == ["a", "c", "e", "b", "d"])
    }

    @Test func moveFromOffsetsToFrontKeepsRelativeOrder() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.move(fromOffsets: 2...4, toOffset: 0)
        #expect(deck.cards == ["c", "d", "e", "a", "b"])
    }

    @Test func moveFromOffsetsToOwnPositionReturnsEmptyPermutation() {
        var deck = Deck(cards: ["a", "b", "c"])
        #expect(deck.move(fromOffsets: [1], toOffset: 2).cycle.isEmpty)
        #expect(deck.cards == ["a", "b", "c"])
    }

    @Test func moveLandsElementAtLaterDestination() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.move(from: 1, to: 3)
        #expect(deck.cards == ["a", "c", "d", "b", "e"])
    }

    @Test func moveToEarlierIndexShiftsOthersBack() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.move(from: 3, to: 0)
        #expect(deck.cards == ["d", "a", "b", "c", "e"])
    }

    @Test func moveToSameIndexReturnsEmptyPermutation() {
        var deck = Deck(cards: ["a", "b", "c"])
        #expect(deck.move(from: 1, to: 1).cycle.isEmpty)
    }

    @Test func partitionIsStableAndReturnsFirstMovedIndex() {
        var deck = Deck(cards: (0..<7).map(String.init))
        let pivot = deck.partition { Int($0)! % 2 == 1 }
        #expect(deck.cards == ["0", "2", "4", "6", "1", "3", "5"])
        #expect(pivot == 4)
    }

    @Test func partitionWithNoMatchesReturnsEndIndex() {
        var deck = Deck(cards: ["a", "b", "c"])
        let pivot = deck.partition { $0 == "z" }
        #expect(deck.cards == ["a", "b", "c"])
        #expect(pivot == deck.endIndex)
    }

    @Test func permuteLeavesOffsetsBeyondTheCycleInPlace() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e", "f"])
        deck.permute(using: Permutation(shuffles: 3))
        #expect(deck.cards[3...] == ["d", "e", "f"])
        #expect(deck.cards[..<3].sorted() == ["a", "b", "c"])
    }

    @Test func permuteOnRandomAccessCollectionMatchesPlainCollection() {
        let original = (0..<25).map(String.init)
        var deck = Deck(cards: original)
        var hand = Hand(cards: original)
        hand.permute(using: deck.shuffle())
        #expect(hand.cards == deck.cards)
    }

    @Test func reverseLeavesMiddleElementInPlace() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        let permutation = deck.reverse()
        #expect(deck.cards == ["e", "d", "c", "b", "a"])
        #expect(!permutation.cycle.contains(2))
    }

    @Test func reverseOfEmptyCollectionReturnsEmptyPermutation() {
        var deck = Deck(cards: [])
        #expect(deck.reverse().cycle.isEmpty)
    }

    @Test func reverseOfEvenCountSwapsEveryPair() {
        var deck = Deck(cards: ["a", "b", "c", "d"])
        let permutation = deck.reverse()
        #expect(deck.cards == ["d", "c", "b", "a"])
        #expect(permutation.cycle == [2, 1, 3, 0])
    }

    @Test func rotateMovesIndexToFront() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.rotate(toStartAt: 2)
        #expect(deck.cards == ["c", "d", "e", "a", "b"])
    }

    @Test func rotateSharingFactorWithCountUndoesWithInverted() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e", "f"])
        let permutation = deck.rotate(toStartAt: 2)
        #expect(deck.cards == ["c", "d", "e", "f", "a", "b"])
        deck.permute(using: permutation.inverted)
        #expect(deck.cards == ["a", "b", "c", "d", "e", "f"])
    }

    @Test func rotateToStartIndexLeavesOrder() {
        var deck = Deck(cards: ["a", "b", "c"])
        #expect(deck.rotate(toStartAt: deck.startIndex).cycle.isEmpty)
        #expect(deck.cards == ["a", "b", "c"])
    }

    @Test func shuffleCycleHasNoFixedPoints() {
        let cycle = Permutation(shuffles: 50).cycle
        #expect(Set(cycle).count == cycle.count && cycle.allSatisfy { (0..<50).contains($0) })
        var largest = -1
        let starts = cycle.map { offset in
            defer { largest = max(largest, offset) }
            return offset > largest
        }
        #expect(zip(starts, starts.dropFirst() + [true]).allSatisfy { !($0 && $1) })
    }

    @Test func shuffleKeepsEveryElement() {
        var deck = Deck(cards: (0..<20).map(String.init))
        deck.shuffle()
        #expect(deck.cards.sorted() == (0..<20).map(String.init).sorted())
    }

    @Test func shuffleOfZeroHasNoCycles() {
        #expect(Permutation(shuffles: 0).cycle.isEmpty)
        #expect(Permutation(shuffles: 1).cycle.isEmpty)
    }

    @Test func shuffleUsingGeneratorMatchesArray() {
        var deckGenerator = SeededGenerator(state: 99)
        var arrayGenerator = SeededGenerator(state: 99)
        var deck = Deck(cards: (0..<30).map(String.init))
        var array = (0..<30).map(String.init)
        deck.shuffle(using: &deckGenerator)
        array.shuffle(using: &arrayGenerator)
        #expect(deck.cards == array)
        #expect(deckGenerator.state == arrayGenerator.state)
    }

    @Test func shuffleUsingGeneratorOnSingleElementLeavesItInPlace() {
        var generator = SeededGenerator(state: 3)
        var deck = Deck(cards: ["a"])
        deck.shuffle(using: &generator)
        #expect(deck.cards == ["a"])
    }

    @Test func sortByOrdersDescending() {
        var deck = Deck(cards: ["b", "d", "a", "c"])
        deck.sort(by: >)
        #expect(deck.cards == ["d", "c", "b", "a"])
    }

    @Test func sortOfSortedCollectionReturnsEmptyPermutation() {
        var deck = Deck(cards: ["a", "b", "c"])
        #expect(deck.sort().cycle.isEmpty)
    }

    @Test func sortOrdersAscending() {
        var deck = Deck(cards: ["d", "b", "e", "a", "c"])
        deck.sort()
        #expect(deck.cards == ["a", "b", "c", "d", "e"])
    }

    @Test func squashedWithAppliesBothInOrder() {
        let original = (0..<8).map(String.init)
        for _ in 0..<50 {
            var deck = Deck(cards: original)
            let first = deck.shuffle()
            let second = deck.rotate(toStartAt: 3)
            var replay = Deck(cards: original)
            replay.permute(using: first.squashed(with: second))
            #expect(replay.cards == deck.cards)
        }
    }

    @Test func squashedWithInvertedIsIdentity() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        let permutation = deck.shuffle()
        #expect(permutation.squashed(with: permutation.inverted) == .identity)
    }

    @Test func squashedWithShorterPermutationLeavesLaterOffsetsToTheLonger() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        let swap = deck.move(from: 0, to: 1)
        let reverse = deck.reverse()
        var replay = Deck(cards: ["a", "b", "c", "d", "e"])
        replay.permute(using: swap.squashed(with: reverse))
        #expect(replay.cards == deck.cards)
        #expect(swap.squashed(with: reverse).minimumCount == 5)
    }
}
