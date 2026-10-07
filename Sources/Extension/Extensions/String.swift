// Standalone file: paste it into any Swift project. It has no package dependencies.

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
