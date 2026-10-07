// Standalone file: paste it into any Swift project. It has no package dependencies.

public extension String {

    // MARK: - Variables

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    ///
    ///     "   \n".isBlank // true
    ///     " a ".isBlank   // false
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    // MARK: - Functions

    /// Returns a Boolean value indicating whether the entire string matches a regular expression.
    /// An invalid pattern returns `false` instead of throwing. Swift Regex sets the minimum versions.
    ///
    ///     "2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#) // true
    ///     "Oct 7".matches(pattern: #"\d+"#)                    // false
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
    ///
    ///     "  Hello, world!\n".trimmed // "Hello, world!"
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
