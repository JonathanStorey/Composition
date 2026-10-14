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

@Suite struct CKRecordableTests {

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
