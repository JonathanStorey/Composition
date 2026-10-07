// Standalone file: paste it into any Swift project. It has no package dependencies.

import Foundation

/// A type that can be matched against a user's search query.
///
/// Conforming types only need to list the text that should be searchable.
/// The matching logic comes for free from the default implementation below.
///
///     struct Contact: Searchable {
///         let name: String
///         let email: String
///
///         var searchableText: [String] { [name, email] }
///     }
///
///     contact.matches("jane") // true if the name or email contains "jane"
public protocol Searchable {
    /// The pieces of text that a search query is compared against.
    var searchableText: [String] { get }

    /// Returns a Boolean value indicating whether the value matches the query.
    func matches(_ query: String) -> Bool
}

public extension Searchable {
    /// Default implementation: case- and diacritic-insensitive "contains" matching.
    /// A blank query matches everything, so an empty search field shows all results.
    ///
    /// Requires: Foundation. iOS 9.0+, macOS 10.11+, tvOS 9.0+, watchOS 2.0+.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return searchableText.contains { $0.localizedStandardContains(query) }
    }
}

public extension Sequence where Element: Searchable {
    /// Returns the elements that match the query.
    ///
    ///     contacts.filtered(by: searchText)
    func filtered(by query: String) -> [Element] {
        filter { $0.matches(query) }
    }
}
