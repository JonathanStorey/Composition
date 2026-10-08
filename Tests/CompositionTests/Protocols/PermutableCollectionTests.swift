import Testing
@testable import Composition

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

    @Test func emptyCycleLeavesOrderUnchanged() throws {
        var deck = Deck(cards: ["a", "b", "c"])
        deck.permute(using: try #require(Permutation(cycle: [])))
        #expect(deck.cards == ["a", "b", "c"])
    }

    @Test func invalidCycleReturnsNil() {
        #expect(Permutation(cycle: [0, 2, 0]) == nil)
        #expect(Permutation(cycle: [-1, 1]) == nil)
    }

    @Test func permuteAppliesToLongerCollections() throws {
        var deck = Deck(cards: ["a", "b", "c", "d", "e"])
        deck.permute(using: try #require(Permutation(cycle: [0, 1, 2])))
        #expect(deck.cards == ["c", "a", "b", "d", "e"])
    }

    @Test func permuteMovesEachElementToTheNextOffset() throws {
        var deck = Deck(cards: ["a", "b", "c", "d"])
        deck.permute(using: try #require(Permutation(cycle: [3, 0, 2])))
        #expect(deck.cards == ["d", "b", "a", "c"])
    }

    @Test func singleOffsetLeavesOrderUnchanged() throws {
        var deck = Deck(cards: ["a", "b"])
        deck.permute(using: try #require(Permutation(cycle: [1])))
        #expect(deck.cards == ["a", "b"])
    }
}
