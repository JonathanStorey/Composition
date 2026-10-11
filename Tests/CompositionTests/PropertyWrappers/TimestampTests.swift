// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/TimestampTests.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift, PropertyWrappers/Timestamp.swift]

#if canImport(SwiftUI)
import SwiftUI
import Testing
@testable import Composition

@MainActor
@Suite struct TimestampTests {

    @Test func dateIsTheTimeInsideTheUUID() {
        #expect(Timestamp<Date>(.install).wrappedValue == Date(timestamp: Timestamp<UUID>(.install).wrappedValue))
    }

    @Test func deviceIsSharedAcrossWrappers() {
        #expect(Timestamp<UUID>(.device).wrappedValue == Timestamp<UUID>(.device).wrappedValue)
        #expect(Timestamp<UUID>(.device).wrappedValue.version == 7)
    }

    @Test func identifierAtURLReplacesUnreadableContents() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "Timestamp")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try UUID().uuidString.write(to: url, atomically: true, encoding: .utf8)
        let identifier: UUID = Timestamp<UUID>.identifier(at: url)
        #expect(identifier.version == 7)
        #expect(try String(contentsOf: url, encoding: .utf8) == identifier.uuidString)
    }

    @Test func identifierAtURLStoresAndReusesIdentifier() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "Timestamp")
        let identifier: UUID = Timestamp<UUID>.identifier(at: url)
        #expect(identifier.version == 7)
        #expect(Timestamp<UUID>.identifier(at: url) == identifier)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func installIsSharedAcrossWrappers() {
        #expect(Timestamp<UUID>(.install).wrappedValue == Timestamp<UUID>(.install).wrappedValue)
    }

    @Test func scopeIsKept() {
        #expect(Timestamp<Date>(.scene).scope == .scene)
    }

    @Test func scopesAreIndependent() {
        #expect(Timestamp<UUID>(.install).wrappedValue != Timestamp<UUID>(.view).wrappedValue)
    }

    @Test func viewIsUniquePerWrapper() {
        let first: Timestamp<UUID> = Timestamp(.view)
        #expect(first.wrappedValue.version == 7)
        #expect(first.wrappedValue == first.wrappedValue)
        #expect(first.wrappedValue != Timestamp<UUID>(.view).wrappedValue)
    }
}
#endif
