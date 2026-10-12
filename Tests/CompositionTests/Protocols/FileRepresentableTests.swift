// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentableTests.swift
// dependencies: [Protocols/FileRepresentable.swift]

#if canImport(Foundation) && canImport(UniformTypeIdentifiers)
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Composition

@Suite struct FileRepresentableTests {

    @Test func dataIsKeptAsIs() {
        #expect(Data([1, 2, 3]).fileContents() == Data([1, 2, 3]))
        #expect(Data(fileContents: Data([4])) == Data([4]))
        #expect(Data.contentType.preferredFilenameExtension == "data")
    }

    @Test func optionalUsesTheWrappedTypeAndThrowsForNil() throws {
        #expect(String?.contentType == .plainText)
        #expect(try String?(fileContents: Data("Dune".utf8)) == "Dune")
        #expect(throws: CocoaError.self) { try String?.none.fileContents() }
    }

    @Test func stringIsUTF8Text() throws {
        #expect("Café".fileContents() == Data("Café".utf8))
        #expect(try String(fileContents: Data("Café".utf8)) == "Café")
        #expect(throws: CocoaError.self) { try String(fileContents: Data([0xFF, 0xFE, 0xFD])) }
        #expect(String.contentType.preferredFilenameExtension == "txt")
    }
}
#endif
