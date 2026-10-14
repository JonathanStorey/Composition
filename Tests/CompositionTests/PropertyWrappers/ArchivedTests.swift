// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/ArchivedTests.swift
// dependencies: [PropertyWrappers/Archived.swift]

import Testing
@testable import Composition

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

private struct Bookmark: Codable, Equatable {

    @Archived var url: NSURL
}

@Suite struct ArchivedTests {

    @Test func decodingAnotherClassThrows() throws {
        let data: Data = try JSONEncoder().encode(Archived(wrappedValue: NSString(string: "Dune")))
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Archived<NSURL>.self, from: data) }
    }

    @Test func decodingCorruptDataThrows() throws {
        let data: Data = try JSONEncoder().encode(Data([1, 2, 3]))
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Archived<NSURL>.self, from: data) }
    }

    @Test func roundTripsThroughJSON() throws {
        let bookmark: Bookmark = Bookmark(url: try #require(NSURL(string: "https://example.com")))
        let data: Data = try JSONEncoder().encode(bookmark)
        #expect(try JSONDecoder().decode(Bookmark.self, from: data) == bookmark)
    }
}
#endif

// MARK: - CloudKit + Foundation

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit

extension ArchivedTests {

    @Test func roundTripsRecordReference() throws {
        let id: CKRecord.ID = CKRecord.ID(recordName: "Note.42", zoneID: CKRecordZone.ID(zoneName: "Composition"))
        let reference: Archived<CKRecord.Reference> = Archived(wrappedValue: CKRecord.Reference(recordID: id, action: .deleteSelf))
        let decoded: Archived<CKRecord.Reference> = try JSONDecoder().decode(Archived<CKRecord.Reference>.self, from: JSONEncoder().encode(reference))
        #expect(decoded.wrappedValue.recordID == id)
        #expect(decoded.wrappedValue.action == .deleteSelf)
    }
}
#endif
