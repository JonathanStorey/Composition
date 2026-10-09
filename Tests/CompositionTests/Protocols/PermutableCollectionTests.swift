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

@Suite struct PermutableCollectionTests {

    @Test func permuteLeavesOffsetsBeyondTheCycleInPlace() {
        var deck = Deck(cards: ["a", "b", "c", "d", "e", "f"])
        deck.permute(using: Permutation(shuffles: 3))
        #expect(deck.cards[3...] == ["d", "e", "f"])
        #expect(deck.cards[..<3].sorted() == ["a", "b", "c"])
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
}
