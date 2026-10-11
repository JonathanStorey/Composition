// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StableIdentifierTests.swift
// dependencies: [Extensions/UUID.swift, PropertyWrappers/StableIdentifier.swift]

#if canImport(SwiftUI)
import SwiftUI
import Testing
@testable import Composition

@MainActor
@Suite struct StableIdentifierTests {

    @Test func deviceIsSharedAcrossWrappers() {
        #expect(StableIdentifier(for: .device).wrappedValue == StableIdentifier(for: .device).wrappedValue)
        #expect(StableIdentifier(for: .device).wrappedValue == StableIdentifier.device)
    }

    @Test func identifierAtURLReplacesUnreadableContents() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "StableIdentifier")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not an identifier".write(to: url, atomically: true, encoding: .utf8)
        let identifier: UUID = StableIdentifier.identifier(at: url)
        #expect(identifier.version == 7)
        #expect(try String(contentsOf: url, encoding: .utf8) == identifier.uuidString)
    }

    @Test func identifierAtURLStoresAndReusesIdentifier() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "StableIdentifier")
        let identifier: UUID = StableIdentifier.identifier(at: url)
        #expect(identifier.version == 7)
        #expect(StableIdentifier.identifier(at: url) == identifier)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func installIsSharedAcrossWrappers() {
        #expect(StableIdentifier(for: .install).wrappedValue == StableIdentifier(for: .install).wrappedValue)
        #expect(StableIdentifier(for: .install).wrappedValue == StableIdentifier.install)
    }

    @Test func scopeIsKept() {
        #expect(StableIdentifier(for: .scene).scope == .scene)
    }

    @Test func viewIsTimestampedAndUniquePerWrapper() {
        let first: StableIdentifier = StableIdentifier(for: .view)
        #expect(first.wrappedValue.version == 7)
        #expect(first.wrappedValue == first.wrappedValue)
        #expect(first.wrappedValue != StableIdentifier(for: .view).wrappedValue)
    }
}
#endif
