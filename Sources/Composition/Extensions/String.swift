// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/String.swift
// dependencies: []

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
