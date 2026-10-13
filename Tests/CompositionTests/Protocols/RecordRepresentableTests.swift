// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordRepresentableTests.swift
// dependencies: [Protocols/RecordRepresentable.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation
import Testing
@testable import Composition

@Suite struct RecordRepresentableTests {

    @Test func codableValueRoundTripsThroughTheValueField() throws {
        let record: CKRecord = CKRecord(recordType: Book.recordType)
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record["value"] is Data)
        #expect(try Book(from: record) == Book(pages: 412, title: "Dune"))
    }

    @Test func codableValueThrowsWithoutAValueField() {
        #expect(throws: DecodingError.self) { try Book(from: CKRecord(recordType: Book.recordType)) }
    }

    @Test func recordTypeDropsTheModuleAndJoinsNestedNames() {
        #expect(Book.recordType == "RecordRepresentableTests_Book")
    }

    @Test func recordTypeNameJoinsGenericArguments() {
        #expect(recordTypeName(String(reflecting: Page<Book>.self)[...]) == "RecordRepresentableTests_Page_RecordRepresentableTests_Book")
        #expect(recordTypeName(String(reflecting: [String: Int].self)[...]) == "Dictionary_String_Int")
    }

    @Test func recordTypeNameUsesTheElementOfCollectionsAndOptionals() {
        #expect(recordTypeName(String(reflecting: [Book].self)[...]) == "RecordRepresentableTests_Book")
        #expect(recordTypeName(String(reflecting: Set<String>?.self)[...]) == "String")
    }
}

extension RecordRepresentableTests {

    struct Book: Codable, Equatable, RecordRepresentable {

        let pages: Int
        let title: String
    }

    struct Page<C: Codable>: Codable {

        let items: [C]
    }
}
#endif
