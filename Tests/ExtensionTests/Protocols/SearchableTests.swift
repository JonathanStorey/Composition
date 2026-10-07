import Testing
@testable import Extension

private struct Item: Searchable {
    let title: String
    let tag: String

    var searchableText: [String] { [title, tag] }
}

@Suite struct SearchableTests {
    private let items = [
        Item(title: "Café Menu", tag: "food"),
        Item(title: "Bike Repair", tag: "outdoors"),
    ]

    @Test func matchesIgnoresCaseAndDiacritics() {
        #expect(items[0].matches("cafe"))
        #expect(items[0].matches("MENU"))
        #expect(!items[0].matches("bike"))
    }

    @Test func matchesAnySearchableField() {
        #expect(items[1].matches("outdoor"))
    }

    @Test func blankQueryMatchesEverything() {
        #expect(items.filtered(by: "  ").count == items.count)
    }

    @Test func filteredReturnsOnlyMatches() {
        #expect(items.filtered(by: "repair").map(\.title) == ["Bike Repair"])
    }
}
