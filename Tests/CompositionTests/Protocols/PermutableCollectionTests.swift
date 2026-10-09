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

    subscript(position: Int) -> String {
        get { cards[position] }
        set { cards[position] = newValue }
    }

    func index(after i: Int) -> Int {
        cards.index(after: i)
    }
}

@Suite struct PermutableCollectionTests {

    @Test func destinationsAndSourcesDescribeTheSameMove() {
        #expect(Permutation(destinations: [1, 2, 0, 4, 3]) == Permutation(sources: [2, 0, 1, 4, 3]))
        #expect(Permutation(destinations: [0: 2, 2: 0]) == Permutation(sources: [2: 0, 0: 2]))
    }

    @Test func dictionaryMatchesArrayWithMissingOffsetsInPlace() {
        #expect(Permutation(destinations: [0: 2, 2: 0]) == Permutation(destinations: [2, 1, 0]))
        #expect(Permutation(destinations: [0: 2, 2: 0]).cycle == [2, 0])
    }

    @Test func emptyMappingHasNoCycles() {
        var deck = Deck(cards: ["a", "b"])
        deck.permute(using: Permutation(sources: []))
        #expect(deck.cards == ["a", "b"])
    }

    @Test func fixedPointsAreLeftOutOfTheCycle() {
        #expect(Permutation(sources: [0, 1, 2]).cycle.isEmpty)
        #expect(Permutation(sources: [0, 2, 1, 3]).cycle == [2, 1])
    }

    @Test func mappingIsStoredInFoataOrder() {
        #expect(Permutation(sources: [2, 0, 1, 4, 3]).cycle == [2, 0, 1, 4, 3])
        #expect(Permutation(sources: [3, 2, 1, 0]).cycle == [2, 1, 3, 0])
    }

    @Test func permuteAppliesEachCycle() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.permute(using: Permutation(sources: [2, 0, 1, 4, 3]))
        #expect(deck.cards == ["c", "a", "b", "e", "d"])
    }

    @Test func permuteAppliesToLongerCollections() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.permute(using: Permutation(sources: [2, 0, 1]))
        #expect(deck.cards == ["c", "a", "b", "d", "e"])
    }

    @Test func shuffleIsCanonicalAndReorders() {
        var generator = SeededGenerator(state: 7)
        let permutation = Permutation(shuffles: 20, using: &generator)
        var deck = Deck(cards: (0..<20).map(String.init))
        deck.permute(using: permutation)
        #expect(deck.cards.sorted() == (0..<20).map(String.init).sorted())
        #expect(Permutation(sources: deck.cards.compactMap { Int($0) }) == permutation)
    }

    @Test func shuffleIsReproducibleWithTheSameGenerator() {
        var first = SeededGenerator(state: 42)
        var second = SeededGenerator(state: 42)
        #expect(Permutation(shuffles: 50, using: &first) == Permutation(shuffles: 50, using: &second))
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
}

