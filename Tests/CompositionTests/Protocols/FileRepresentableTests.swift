// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentableTests.swift
// dependencies: [Protocols/FileRepresentable.swift]

// MARK: - Foundation

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct FileRepresentableTests {

    @Test func csvQuotesOnlyFieldsThatNeedIt() throws {
        let rows: [[String]] = [["name", "note"], ["Dune", "Herbert, Frank"], ["Emma", "a \"classic\"\nnovel"]]
        #expect(try String(fileContents: rows.fileContents) == "name,note\r\nDune,\"Herbert, Frank\"\r\nEmma,\"a \"\"classic\"\"\nnovel\"\r\n")
    }

    @Test func csvReadsUnixLineEndingsAndAMissingLastLineEnding() throws {
        #expect(try [[String]](fileContents: Data("a,b\nc,d".utf8)) == [["a", "b"], ["c", "d"]])
        #expect(try [[String]](fileContents: Data()) == [])
    }

    @Test func csvReadsWhatItWrites() throws {
        let rows: [[String]] = [["name", "note"], ["Dune", "Herbert, Frank"], ["Emma", "a \"classic\"\nnovel"], ["", ""]]
        #expect(try [[String]](fileContents: rows.fileContents) == rows)
    }

    @Test func dataIsKeptAsIs() {
        #expect(Data([1, 2, 3]).fileContents == Data([1, 2, 3]))
        #expect(Data(fileContents: Data([4])) == Data([4]))
        #expect(Data.fileExtension == "data")
    }

    @Test func optionalUsesTheWrappedTypeAndThrowsForNil() throws {
        #expect(String?.fileExtension == "txt")
        #expect(try String?(fileContents: Data("Dune".utf8)) == "Dune")
        #expect(throws: CocoaError.self) { try String?.none.fileContents }
    }

    @Test func stringIsUTF8Text() throws {
        #expect("Café".fileContents == Data("Café".utf8))
        #expect(try String(fileContents: Data("Café".utf8)) == "Café")
        #expect(throws: CocoaError.self) { try String(fileContents: Data([0xFF, 0xFE, 0xFD])) }
    }
}
#endif

// MARK: - AppKit + Foundation

#if canImport(AppKit) && canImport(Foundation) && !targetEnvironment(macCatalyst)
import AppKit

extension FileRepresentableTests {

    @Test func attributedStringRoundTripsThroughRichText() throws {
        var text: AttributedString = AttributedString("Dune")
        text.appKit.underlineStyle = .single
        let read: AttributedString = try AttributedString(fileContents: text.fileContents)
        #expect(String(read.characters) == "Dune")
        #expect(read.appKit.underlineStyle == .single)
    }
}
#endif
