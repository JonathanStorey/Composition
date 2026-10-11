// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/String.swift
// dependencies: []

public extension String {

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    /// The string's words, punctuation, symbols, whitespace, and newlines, split by Unicode word boundaries, with any change written back into the string.
    var segments: SegmentView {
        get { SegmentView(base: self) }
        set { self = newValue.base }
    }

    /// The string's words, split by Unicode word boundaries, with any change written back into the string.
    var words: WordView {
        get { WordView(segments: segments) }
        set { self = newValue.segments.base }
    }

    /// Returns a Boolean value indicating whether the entire string matches a regular expression.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func matches(pattern: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return wholeMatch(of: regex) != nil
    }
}

public extension String {

    /// A piece of a string between two Unicode word boundaries, following UAX #29.
    enum Segment: Hashable, Sendable {

        /// Letters and numbers, including the apostrophes, periods, commas, and underscores that UAX #29 keeps inside a word.
        case word(Substring)

        /// A run of spaces, or a single tab.
        case whitespace(Substring)

        /// A single line break, with a carriage return and line feed counting as one.
        case newline(Substring)

        /// A single punctuation mark.
        case punctuation(Substring)

        /// A single symbol, emoji, or other character.
        case symbol(Substring)

        /// Creates the segment of the kind its text belongs to.
        fileprivate init(_ text: Substring) {
            let first: Character = text.first ?? " "
            if first.isNewline {
                self = .newline(text)
            } else if first.isWhitespace {
                self = .whitespace(text)
            } else if text.contains(where: { $0.isLetter || $0.isNumber }) {
                self = .word(text)
            } else if first.isPunctuation {
                self = .punctuation(text)
            } else {
                self = .symbol(text)
            }
        }

        /// The text of the segment.
        public var text: Substring {
            switch self {
            case .word(let text), .whitespace(let text), .newline(let text), .punctuation(let text), .symbol(let text): text
            }
        }
    }

    /// A two-way view of a string's segments that writes any replaced segment back into the string.
    struct SegmentView: BidirectionalCollection, Sendable {

        fileprivate var base: String

        /// The position one past the last segment.
        public var endIndex: Index {
            Index(range: base.endIndex..<base.endIndex)
        }

        /// The position of the first segment.
        public var startIndex: Index {
            Index(range: base.startIndex..<end(from: base.startIndex))
        }

        /// The segment at the position, which replaces that segment's text in the string when set.
        public subscript(position: Index) -> Segment {
            get { Segment(base[position.range]) }
            set { base.replaceSubrange(position.range, with: newValue.text) }
        }

        /// Returns the position of the segment that follows the one at the given position.
        public func index(after i: Index) -> Index {
            Index(range: i.range.upperBound..<end(from: i.range.upperBound))
        }

        /// Returns the position of the segment that precedes the one at the given position.
        public func index(before i: Index) -> Index {
            var start: String.Index = base.index(before: i.range.lowerBound)
            while start > base.startIndex, !isBoundary(at: start) {
                base.formIndex(before: &start)
            }
            return Index(range: start..<i.range.lowerBound)
        }

        /// Returns the end of the segment that starts at the position.
        private func end(from start: String.Index) -> String.Index {
            guard start < base.endIndex else { return start }
            var end: String.Index = base.index(after: start)
            while end < base.endIndex, !isBoundary(at: end) {
                base.formIndex(after: &end)
            }
            return end
        }

        /// Returns a Boolean value indicating whether UAX #29 places a word boundary between the character before the position and the one at it.
        private func isBoundary(at position: String.Index) -> Bool {
            let before: WordBreak = WordBreak(base[base.index(before: position)])
            let right: WordBreak = WordBreak(base[position])
            if before == .newline || right == .newline { return true }
            if before == .space && right == .space { return false }
            if right == .format { return false }
            guard let leftIndex: String.Index = significantIndex(before: position) else { return true }
            let left: WordBreak = WordBreak(base[leftIndex])
            let farLeft: WordBreak? = significantIndex(before: leftIndex).map { WordBreak(base[$0]) }
            let farRight: WordBreak? = significantIndex(after: position).map { WordBreak(base[$0]) }
            if left.isLetter && right.isLetter { return false }
            if left.isLetter && right.isMidLetter && farRight?.isLetter == true { return false }
            if farLeft?.isLetter == true && left.isMidLetter && right.isLetter { return false }
            if left == .hebrewLetter && right == .singleQuote { return false }
            if left == .hebrewLetter && right == .doubleQuote && farRight == .hebrewLetter { return false }
            if farLeft == .hebrewLetter && left == .doubleQuote && right == .hebrewLetter { return false }
            if (left.isLetter || left == .numeric) && right == .numeric { return false }
            if left == .numeric && right.isLetter { return false }
            if farLeft == .numeric && left.isMidNum && right == .numeric { return false }
            if left == .numeric && right.isMidNum && farRight == .numeric { return false }
            if left == .katakana && right == .katakana { return false }
            if (left.isWordPart || left == .extendNumLet) && right == .extendNumLet { return false }
            return !(left == .extendNumLet && right.isWordPart)
        }

        /// Returns the position of the nearest character after the position that is not a format character.
        private func significantIndex(after position: String.Index) -> String.Index? {
            base[base.index(after: position)...].firstIndex { WordBreak($0) != .format }
        }

        /// Returns the position of the nearest character before the position that is not a format character.
        private func significantIndex(before position: String.Index) -> String.Index? {
            base[..<position].lastIndex { WordBreak($0) != .format }
        }
    }

    /// A two-way view of a string's words that writes any replaced word back into the string.
    struct WordView: BidirectionalCollection, Sendable {

        /// A position of a word, shared with the string's segments.
        public typealias Index = SegmentView.Index

        fileprivate var segments: SegmentView

        /// Returns a Boolean value indicating whether the segment is a word.
        private static func isWord(_ segment: Segment) -> Bool {
            if case .word = segment { true } else { false }
        }

        /// The position one past the last word.
        public var endIndex: Index {
            segments.endIndex
        }

        /// The position of the first word.
        public var startIndex: Index {
            segments.firstIndex(where: Self.isWord) ?? endIndex
        }

        /// The word at the position, which replaces that word in the string when set.
        public subscript(position: Index) -> Substring {
            get { segments[position].text }
            set { segments[position] = .word(newValue) }
        }

        /// Returns the position of the word that follows the one at the given position.
        public func index(after i: Index) -> Index {
            segments[segments.index(after: i)...].firstIndex(where: Self.isWord) ?? endIndex
        }

        /// Returns the position of the word that precedes the one at the given position.
        public func index(before i: Index) -> Index {
            segments[..<i].lastIndex(where: Self.isWord) ?? segments.startIndex
        }
    }
}

public extension String.SegmentView {

    /// A position of a segment in a string.
    struct Index: Comparable, Sendable {

        fileprivate let range: Range<String.Index>

        /// Returns a Boolean value indicating whether the first segment comes before the second.
        public static func < (lhs: Index, rhs: Index) -> Bool {
            lhs.range.lowerBound < rhs.range.lowerBound
        }
    }
}

/// The UAX #29 word break property of a character, reduced to the values the word boundary rules compare.
fileprivate enum WordBreak {

    case doubleQuote
    case extendNumLet
    case format
    case hebrewLetter
    case katakana
    case letter
    case midLetter
    case midNum
    case midNumLet
    case newline
    case numeric
    case other
    case singleQuote
    case space

    /// Creates the word break property of the character from its first Unicode scalar.
    init(_ character: Character) {
        guard !character.isNewline, let scalar: Unicode.Scalar = character.unicodeScalars.first else {
            self = .newline
            return
        }
        let properties: Unicode.Scalar.Properties = scalar.properties
        switch scalar.value {
        case 0x22: self = .doubleQuote
        case 0x27: self = .singleQuote
        case 0x2E, 0x2018, 0x2019, 0x2024, 0xFE52, 0xFF07, 0xFF0E: self = .midNumLet
        case 0x3A, 0xB7, 0x387, 0x55F, 0x5F4, 0x2027, 0xFE13, 0xFE55, 0xFF1A: self = .midLetter
        case 0x2C, 0x3B, 0x37E, 0x589, 0x60C, 0x60D, 0x66C, 0x7F8, 0x2044, 0xFE10, 0xFE14, 0xFE50, 0xFE54, 0xFF0C, 0xFF1B: self = .midNum
        case 0x202F: self = .extendNumLet
        case 0xA0, 0x2007: self = .other
        case 0x5D0...0x5EA, 0x5EF...0x5F2: self = .hebrewLetter
        case 0xFB1D...0xFB4F where properties.isAlphabetic: self = .hebrewLetter
        case 0x3031...0x3035, 0x309B...0x309C, 0x30A0...0x30FA, 0x30FC...0x30FF, 0x31F0...0x31FF, 0x32D0...0x32FE, 0x3300...0x3357, 0xFF66...0xFF9D: self = .katakana
        case 0x3040...0x309F, 0x0E00...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF, 0x1950...0x19DF, 0x1A20...0x1AAF, 0xAA60...0xAADF: self = .other
        default:
            switch properties.generalCategory {
            case .format: self = .format
            case .connectorPunctuation: self = .extendNumLet
            case .spaceSeparator: self = .space
            case .decimalNumber: self = .numeric
            default: self = properties.isAlphabetic && !properties.isIdeographic ? .letter : .other
            }
        }
    }

    /// A Boolean value indicating whether the property is a letter, Hebrew or otherwise.
    var isLetter: Bool {
        self == .letter || self == .hebrewLetter
    }

    /// A Boolean value indicating whether the property can join two letters, as in "can't" and "e.g".
    var isMidLetter: Bool {
        self == .midLetter || self == .midNumLet || self == .singleQuote
    }

    /// A Boolean value indicating whether the property can join two numbers, as in "3.14" and "1,000".
    var isMidNum: Bool {
        self == .midNum || self == .midNumLet || self == .singleQuote
    }

    /// A Boolean value indicating whether the property starts or continues a word that an underscore can join.
    var isWordPart: Bool {
        isLetter || self == .numeric || self == .katakana
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
