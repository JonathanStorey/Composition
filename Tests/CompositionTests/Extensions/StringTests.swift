// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/StringTests.swift
// dependencies: [Extensions/String.swift]

import Testing
@testable import Composition

@Suite struct StringTests {

    @Test func isBlankDetectsEmptyAndWhitespaceOnly() {
        #expect("".isBlank)
        #expect(" \t\n".isBlank)
        #expect(!" a ".isBlank)
    }

    @Test func matchesPatternRequiresWholeMatch() {
        #expect("2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#))
        #expect(!"Due 2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#))
    }

    @Test func matchesPatternReturnsFalseForInvalidPattern() {
        #expect(!"abc".matches(pattern: "("))
    }

    @Test func segmentsClassifyEveryKind() {
        let expected: [String.Segment] = [.word("Hi"), .punctuation(","), .whitespace("  "), .word("you"), .punctuation("!"), .newline("\r\n"), .symbol("$"), .word("5")]
        #expect(Array("Hi,  you!\r\n$5".segments) == expected)
    }

    @Test func segmentsFollowUnicodeWordRules() {
        #expect(Array("don’t can't 3.14 1,000 snake_case e.g. well-known".words) == ["don’t", "can't", "3.14", "1,000", "snake_case", "e.g", "well", "known"])
        #expect(Array("'tis dogs'".segments) == [.punctuation("'"), .word("tis"), .whitespace(" "), .word("dogs"), .punctuation("'")])
    }

    @Test func segmentsIsEmptyForEmptyString() {
        #expect("".segments.isEmpty)
    }

    @Test func segmentsReadBackwardAndRebuildString() {
        let text: String = "Hello, brave new-world!\n"
        #expect(text.segments.reversed().elementsEqual(Array(text.segments).reversed()))
        #expect(text.segments.map(\.text).joined() == text)
    }

    @Test func segmentsWriteChangesBackIntoString() {
        var text: String = "Hello, world"
        let index: String.SegmentView.Index = text.segments.index(after: text.segments.startIndex)
        text.segments[index] = .punctuation("!")
        #expect(text == "Hello! world")
    }

    @Test func wordsIsEmptyWithoutLettersOrNumbers() {
        #expect(" ,.! ".words.isEmpty)
    }

    @Test func wordsReadForwardAndBackward() {
        let text: String = "Hello, brave new-world!"
        #expect(Array(text.words) == ["Hello", "brave", "new", "world"])
        #expect(Array(text.words.reversed()) == ["world", "new", "brave", "Hello"])
    }

    @Test func wordsWriteChangesBackIntoString() {
        var text: String = "Hello,  world!"
        let index: String.WordView.Index = text.words.index(after: text.words.startIndex)
        text.words[index] = "Swift"
        #expect(text == "Hello,  Swift!")
    }
}

// MARK: - Foundation

#if canImport(Foundation)
extension StringTests {

    @Test func trimmedRemovesSurroundingWhitespace() {
        #expect("  Hello, world!\n".trimmed == "Hello, world!")
        #expect("no-op".trimmed == "no-op")
    }
}
#endif
