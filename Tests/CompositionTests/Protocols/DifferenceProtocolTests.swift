// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DifferenceProtocolTests.swift
// dependencies: [Protocols/DifferenceProtocol.swift]

import Testing
@testable import Composition

@Suite struct DifferenceProtocolTests {

    @Test func charactersReplaceTheChangedLetter() {
        #expect(StringDifference(from: "cat", to: "bat", by: .characters).changes == [.replaced("c", with: "b"), .unchanged("at")])
    }

    @Test func emptyOriginalInsertsEverything() {
        #expect(StringDifference(from: "", to: "hello world", by: .words).changes == [.inserted("hello world")])
    }

    @Test func identicalStringsAreOneUnchangedRun() {
        #expect(StringDifference(from: "same text", to: "same text", by: .words).changes == [.unchanged("same text")])
    }

    @Test func linesKeepTheirLineBreaks() {
        #expect(StringDifference(from: "a\nb\nc\n", to: "a\nB\nc\n", by: .lines).changes == [.unchanged("a\n"), .replaced("b\n", with: "B\n"), .unchanged("c\n")])
    }

    @Test func originalAndUpdatedRebuildBothStrings() {
        let original: String = "The quick brown fox, sadly, jumps."
        let updated: String = "A quick red fox jumps over it!"
        for granularity in [StringDifference.Granularity.characters, .words, .lines] {
            let difference: StringDifference = StringDifference(from: original, to: updated, by: granularity)
            #expect(difference.original == original)
            #expect(difference.updated == updated)
        }
    }

    @Test func wordsRemoveATrailingWordWithItsSpace() {
        #expect(StringDifference(from: "big cat today", to: "big cat", by: .words).changes == [.unchanged("big cat"), .removed(" today")])
    }

    @Test func wordsReplaceWholeWords() {
        #expect(StringDifference(from: "the quick fox", to: "the slow fox", by: .words).changes == [.unchanged("the "), .replaced("quick", with: "slow"), .unchanged(" fox")])
    }
}

// MARK: - SwiftUI

#if canImport(SwiftUI)
import SwiftUI

extension DifferenceProtocolTests {

    @Test func attributedShowsBothSidesAndStrikesTheRemoval() {
        let attributed: AttributedString = StringDifference(from: "a cat", to: "a dog", by: .words).attributed
        let struck: [String] = attributed.runs.filter { $0[AttributeScopes.SwiftUIAttributes.StrikethroughStyleAttribute.self] != nil }.map { String(attributed[$0.range].characters) }
        #expect(String(attributed.characters) == "a catdog")
        #expect(struck == ["cat"])
    }
}
#endif
