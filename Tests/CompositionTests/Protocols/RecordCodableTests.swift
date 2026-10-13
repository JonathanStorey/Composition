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
        let record: CKRecord = CKRecord(recordType: recordTypeName(of: Book.self))
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record["value"] is Data)
        #expect(try Book(from: record) == Book(pages: 412, title: "Dune"))
    }

    @Test func codableValueThrowsWithoutAValueField() {
        #expect(throws: DecodingError.self) { try Book(from: CKRecord(recordType: recordTypeName(of: Book.self))) }
    }

    @Test func identifiedRecordIsNamedByTheIDInTheZone() throws {
        let note: Note = Note(id: UUID(), text: "Dune")
        let record: CKRecord = try note.record(zone: "Reader")
        #expect(record.recordID.recordName == note.id.uuidString)
        #expect(record.recordID.zoneID.zoneName == "Reader")
        #expect(try Note(from: record) == note)
    }

    @Test func recordHoldsTheFieldsUnderTheTypeNameAndZone() throws {
        let record: CKRecord = try Book(pages: 412, title: "Dune").record(id: "dune")
        #expect(record.recordType == recordTypeName(of: Book.self))
        #expect(record.recordID.recordName == "dune")
        #expect(record.recordID.zoneID.zoneName == "Composition")
        #expect(try Book(from: record) == Book(pages: 412, title: "Dune"))
    }

    @Test func recordTypeNameDropsTheModuleAndJoinsNestedNames() {
        #expect(recordTypeName(of: Book.self) == "RecordCodableTests_Book")
    }

    @Test func recordTypeNameJoinsGenericArguments() {
        #expect(recordTypeName(of: Page<Book>.self) == "RecordCodableTests_Page_RecordCodableTests_Book")
        #expect(recordTypeName(of: [String: Int].self) == "Dictionary_String_Int")
    }

    @Test func recordTypeNameUsesTheElementOfCollectionsAndOptionals() {
        #expect(recordTypeName(of: [Book].self) == "RecordCodableTests_Book")
        #expect(recordTypeName(of: Set<String>?.self) == "String")
    }
}

extension RecordCodableTests {

    struct Book: Codable, Equatable, RecordCodable {

        let pages: Int
        let title: String
    }

    struct Note: Codable, Equatable, Identifiable, RecordCodable {

        let id: UUID
        let text: String
    }

    struct Page<C: Codable>: Codable {

        let items: [C]
    }
}
#endif
