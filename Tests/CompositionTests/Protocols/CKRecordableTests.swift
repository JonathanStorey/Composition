// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/CKRecordableTests.swift
// dependencies: [Protocols/CKRecordable.swift]

#if canImport(CloudKit)
import CloudKit
import Testing
@testable import Composition

private struct Note: CKRecordable, Equatable {

    let title: String

    init(title: String) {
        self.title = title
    }

    init(from record: CKRecord) throws {
        guard let title: String = record["title"] as? String else { throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: [], debugDescription: "The record has no title.")) }
        self.title = title
    }

    func encode(to record: CKRecord) throws {
        record["title"] = title
    }
}

private struct Page: Codable, CKRecordable, Equatable, Identifiable {

    let id: Int
    var text: String
}

private struct Volume: Codable, CKRecordable, Identifiable {

    let id: Int
    var pages: [Page]
}

@Suite struct CKRecordableTests {

    @Test func codableTypesReadAndWriteTheirOwnFields() throws {
        let record: CKRecord = CKRecord(recordType: "Page", recordID: CKRecord.ID(recordName: "Page.7"))
        try Page(id: 7, text: "Hello").encode(to: record)
        #expect(record.allKeys() == ["text"])
        #expect(try Page(from: record) == Page(id: 7, text: "Hello"))
    }

    @Test func codableTypesNeedASourceToReadChildren() throws {
        let record: CKRecord = CKRecord(recordType: "Volume", recordID: CKRecord.ID(recordName: "Volume.1"))
        try Volume(id: 1, pages: [Page(id: 1, text: "A")]).encode(to: record)
        #expect(record.allKeys().isEmpty)
        #expect(throws: DecodingError.self) { try Volume(from: record) }
    }

    @Test func roundTripsThroughARecord() throws {
        let record: CKRecord = CKRecord(recordType: "Note")
        try Note(title: "Dune").encode(to: record)
        #expect(try Note(from: record) == Note(title: "Dune"))
    }

    @Test func throwsWhenTheRecordLacksTheField() {
        #expect(throws: DecodingError.self) { try Note(from: CKRecord(recordType: "Note")) }
    }
}
#endif
