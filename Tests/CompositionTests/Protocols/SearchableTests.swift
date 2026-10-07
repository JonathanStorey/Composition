#if canImport(Foundation)
import Testing
@testable import Composition

private struct Item: Searchable {

    let tag: String
    let title: String

    var searchableText: [String] { [title, tag] }
}

@Suite struct SearchableTests {

    private let items = [
        Item(tag: "food", title: "Café Menu"),
        Item(tag: "outdoors", title: "Bike Repair"),
    ]

    @Test func blankQueryMatchesEverything() {
        #expect(items.filtered(by: "  ").count == items.count)
    }

    @Test func filteredReturnsOnlyMatches() {
        #expect(items.filtered(by: "repair").map(\.title) == ["Bike Repair"])
    }

    @Test func matchesAnySearchableField() {
        #expect(items[1].matches("outdoor"))
    }

    @Test func matchesIgnoresCaseAndDiacritics() {
        #expect(items[0].matches("cafe"))
        #expect(items[0].matches("MENU"))
        #expect(!items[0].matches("bike"))
    }
}
#endif
