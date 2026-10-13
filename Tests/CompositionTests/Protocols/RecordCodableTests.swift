// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordCodableTests.swift
// dependencies: [Protocols/RecordCodable.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation
import Testing
@testable import Composition

@Suite struct RecordCodableTests {

    @Test func codableValueRoundTripsThroughTheValueField() throws {
        let record: CKRecord = CKRecord(recordType: "Book")
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record["value"] is Data)
        #expect(try Book(from: record) == Book(pages: 412, title: "Dune"))
    }

    @Test func codableValueThrowsWithoutAValueField() {
        #expect(throws: DecodingError.self) { try Book(from: CKRecord(recordType: "Book")) }
    }

    @Test func encodeLeavesTheRecordsIdentityAsItIs() throws {
        let record: CKRecord = CKRecord(recordType: "Book", recordID: CKRecord.ID(recordName: "dune", zoneID: CKRecordZone.ID(zoneName: "Library")))
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record.recordType == "Book")
        #expect(record.recordID.recordName == "dune")
        #expect(record.recordID.zoneID.zoneName == "Library")
    }
}

extension RecordCodableTests {

    struct Book: Codable, Equatable, RecordCodable {

        let pages: Int
        let title: String
    }
}
#endif
