public extension String {
    
    /// The string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
