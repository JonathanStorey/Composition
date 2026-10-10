// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/StringTests.swift
// dependencies: [Extensions/RangeReplaceableCollection.swift, Extensions/String.swift]

import Testing
@testable import Composition

@Suite struct StringTests {

    @Test func differenceFromBaseRoundTripsThroughApply() throws {
        var text: String = "kitten"
        try text.apply("sitting".difference(from: "kitten"))
        #expect(text == "sitting")
        #expect(String.Patch.self == CollectionDifference<Character>.self)
    }

    @Test func differenceFromEmptyBaseInsertsEveryCharacter() throws {
        let patch: CollectionDifference<Character> = "abc".difference(from: "")
        var text: String = ""
        try text.apply(patch)
        #expect(patch.insertions.count == 3 && patch.removals.isEmpty)
        #expect(text == "abc")
    }

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
