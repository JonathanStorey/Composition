// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DifferenceProtocol.swift
// dependencies: [Extensions/CollectionDifference.swift]

/// A description of how one value differs from another, listed as a sequence of changes.
public protocol DifferenceProtocol {

    /// A single change that turns one value toward another.
    associatedtype Change

    /// The changes that make up the difference, in the order they apply.
    var changes: [Change] { get }
}

/// The difference between two strings, compared character by character, word by word, or line by line.
public struct StringDifference: DifferenceProtocol, Equatable, Sendable {

    /// The runs of unchanged, inserted, removed, and replaced text that turn the original string into the updated one.
    public let changes: [Change]

    /// Creates the difference that turns the original string into the updated one, comparing pieces of the given granularity.
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public init(from original: String, to updated: String, by granularity: Granularity) {
        let old: [Substring] = granularity.tokens(of: original)
        let new: [Substring] = granularity.tokens(of: updated)
        let difference: CollectionDifference<Substring> = new.difference(from: old)
        let removed: Set<Int> = Set(difference.removals.map(\.offset))
        let inserted: Set<Int> = Set(difference.insertions.map(\.offset))
        var changes: [Change] = []
        var oldIndex: Int = 0
        var newIndex: Int = 0
        while oldIndex < old.count || newIndex < new.count {
            let removal: String = Self.run(of: old, from: &oldIndex, matching: removed)
            let insertion: String = Self.run(of: new, from: &newIndex, matching: inserted)
            if !removal.isEmpty, !insertion.isEmpty {
                changes.append(.replaced(removal, with: insertion))
            } else if !removal.isEmpty {
                changes.append(.removed(removal))
            } else if !insertion.isEmpty {
                changes.append(.inserted(insertion))
            } else if case .unchanged(let text)? = changes.last {
                changes[changes.count - 1] = .unchanged(text + old[oldIndex])
                oldIndex += 1
                newIndex += 1
            } else {
                changes.append(.unchanged(String(old[oldIndex])))
                oldIndex += 1
                newIndex += 1
            }
        }
        self.changes = changes
    }

    /// Returns the text of the consecutive pieces whose offsets are in the set, starting at the index and advancing it past them.
    private static func run(of tokens: [Substring], from index: inout Int, matching offsets: Set<Int>) -> String {
        var text: String = ""
        while index < tokens.count, offsets.contains(index) {
            text += tokens[index]
            index += 1
        }
        return text
    }

    /// The string the difference starts from.
    public var original: String {
        changes.reduce(into: "") { text, change in
            switch change {
            case .unchanged(let piece), .removed(let piece), .replaced(let piece, _): text += piece
            case .inserted: break
            }
        }
    }

    /// The string the difference ends with.
    public var updated: String {
        changes.reduce(into: "") { text, change in
            switch change {
            case .unchanged(let piece), .inserted(let piece), .replaced(_, let piece): text += piece
            case .removed: break
            }
        }
    }
}

public extension StringDifference {

    /// One run of text in a string difference.
    enum Change: Equatable, Sendable {

        /// Text both strings share.
        case unchanged(String)

        /// Text only the updated string has.
        case inserted(String)

        /// Text only the original string has.
        case removed(String)

        /// Text the updated string has in place of the original's text at the same spot.
        case replaced(String, with: String)
    }

    /// The size of the pieces a string difference compares, defined by which neighboring characters stay in one piece.
    struct Granularity: Sendable {

        private let joins: @Sendable (Character, Character) -> Bool

        /// Creates a granularity that keeps a character in the same piece as the one before it when the closure returns true.
        public init(joining joins: @escaping @Sendable (_ previous: Character, _ next: Character) -> Bool) {
            self.joins = joins
        }

        /// Compares single characters.
        public static var characters: Granularity {
            Granularity { _, _ in false }
        }

        /// Compares whole lines, each keeping its line break.
        public static var lines: Granularity {
            Granularity { previous, _ in !previous.isNewline }
        }

        /// Compares words, runs of whitespace, and single punctuation marks.
        public static var words: Granularity {
            Granularity { previous, next in (previous.isLetter || previous.isNumber) && (next.isLetter || next.isNumber) || previous.isWhitespace && next.isWhitespace }
        }

        /// Returns the text split into pieces, which joined in order rebuild the text exactly.
        fileprivate func tokens(of text: String) -> [Substring] {
            var tokens: [Substring] = []
            var start: String.Index = text.startIndex
            for index in text.indices.dropFirst() where !joins(text[text.index(before: index)], text[index]) {
                tokens.append(text[start..<index])
                start = index
            }
            if start < text.endIndex {
                tokens.append(text[start...])
            }
            return tokens
        }
    }
}

// MARK: - SwiftUI

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension StringDifference {

    /// Returns the text underlined in green, marking it as inserted.
    private static func inserted(_ text: String) -> AttributedString {
        var result: AttributedString = AttributedString(text)
        result[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = .single
        result[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = .green
        return result
    }

    /// Returns the text struck through in red, marking it as removed.
    private static func removed(_ text: String) -> AttributedString {
        var result: AttributedString = AttributedString(text)
        result[AttributeScopes.SwiftUIAttributes.StrikethroughStyleAttribute.self] = .single
        result[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = .red
        return result
    }

    /// The changes as one attributed string, with removed text struck through in red and inserted text underlined in green.
    var attributed: AttributedString {
        changes.reduce(into: AttributedString()) { result, change in
            switch change {
            case .unchanged(let text): result += AttributedString(text)
            case .inserted(let text): result += Self.inserted(text)
            case .removed(let text): result += Self.removed(text)
            case .replaced(let old, let new): result += Self.removed(old) + Self.inserted(new)
            }
        }
    }
}
#endif
