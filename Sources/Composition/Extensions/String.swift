// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/String.swift
// dependencies: [Extensions/RangeReplaceableCollection.swift, Protocols/Patchable.swift]

public extension String {

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    /// Returns a Boolean value indicating whether the entire string matches a regular expression.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func matches(pattern: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return wholeMatch(of: regex) != nil
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension String: Patchable {

    /// Returns the difference that turns the base string into this string.
    public func difference(from base: String) -> CollectionDifference<Character> {
        difference(from: base, by: ==)
    }
}

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

public extension String {

    /// The string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
