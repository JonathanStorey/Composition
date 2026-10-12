// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentableTests.swift
// dependencies: [Protocols/FileRepresentable.swift]

#if canImport(Foundation) && canImport(UniformTypeIdentifiers)
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Composition

@Suite struct FileRepresentableTests {

    @Test func dataIsKeptAsIsAndPrefersData() {
        #expect(Data([1, 2, 3]).fileContents == Data([1, 2, 3]))
        #expect(Data(fileContents: Data([4])) == Data([4]))
        #expect(Data.preferredFilenameExtension == "data")
    }

    @Test func optionalUsesTheWrappedTypeAndThrowsForNil() throws {
        #expect(String?.contentType == .utf8PlainText)
        #expect(try String?(fileContents: Data("Dune".utf8)) == "Dune")
        #expect(throws: CocoaError.self) { try String?.none.fileContents }
    }

    @Test func stringIsUTF8Text() throws {
        #expect("Café".fileContents == Data("Café".utf8))
        #expect(try String(fileContents: Data("Café".utf8)) == "Café")
        #expect(throws: CocoaError.self) { try String(fileContents: Data([0xFF, 0xFE, 0xFD])) }
    }

    @Test func stringPrefersTheTxtExtension() {
        #expect(UTType.utf8PlainText.preferredFilenameExtension == "txt")
        #expect(String.preferredFilenameExtension == "txt")
    }

    @Test func utf8PlainTextRelatesToTxtButNotToMarkdownOrJSON() throws {
        let txt: UTType = try #require(UTType(filenameExtension: "txt"))
        let markdown: UTType = try #require(UTType(filenameExtension: "md"))
        let json: UTType = try #require(UTType(filenameExtension: "json"))
        #expect(UTType.utf8PlainText.conforms(to: txt))
        #expect(!UTType.utf8PlainText.conforms(to: markdown) && !markdown.conforms(to: .utf8PlainText))
        #expect(!UTType.utf8PlainText.conforms(to: json) && !json.conforms(to: .utf8PlainText))
    }
}
#endif
