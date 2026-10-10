// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Searchable.swift
// dependencies: [Extensions/String.swift]

#if canImport(Foundation)
import Foundation

/// A type that can be matched against a search query.
public protocol Searchable {

    /// The pieces of text that a search query is compared against.
    var searchableText: [String] { get }

    /// Returns a Boolean value indicating whether the value matches the query.
    func matches(_ query: String) -> Bool
}

public extension Searchable {

    /// Matches when any searchable text contains the query, ignoring case and diacritics. A blank query matches everything.
    func matches(_ query: String) -> Bool {
        let query: String = query.trimmed
        guard !query.isEmpty else { return true }
        return searchableText.contains { $0.localizedStandardContains(query) }
    }
}

public extension Sequence where Element: Searchable {

    /// Returns the elements that match the query.
    func filtered(by query: String) -> [Element] {
        filter { $0.matches(query) }
    }
}
#endif
