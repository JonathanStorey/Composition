import Foundation

public extension String {
    /// The string with leading and trailing whitespace and newlines removed.
    ///
    ///     "  Hello, world!\n".trimmed // "Hello, world!"
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    ///
    ///     "   \n".isBlank // true
    ///     " a ".isBlank   // false
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
