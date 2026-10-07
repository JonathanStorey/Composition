// Standalone file: paste it into any Swift project. It has no package dependencies.

// MARK: - Variables

public extension String {

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    ///
    /// Requires: Swift 5.2+. Standard library only, so it works on every platform.
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}

#if canImport(Foundation)
import Foundation

public extension String {

    /// The string with leading and trailing whitespace and newlines removed.
    ///
    /// Requires: Foundation. iOS 2.0+, macOS 10.0+, tvOS 9.0+, watchOS 2.0+.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif

// MARK: - Functions

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension String {

    /// Returns a Boolean value indicating whether the entire string matches a regular expression.
    /// An invalid pattern returns `false` instead of throwing.
    ///
    ///     "2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#) // true
    ///     "Oct 7".matches(pattern: #"\d+"#)                    // false
    ///
    /// Requires: Swift 5.7+ (Swift Regex). Standard library only, no Foundation.
    func matches(pattern: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return wholeMatch(of: regex) != nil
    }
}
