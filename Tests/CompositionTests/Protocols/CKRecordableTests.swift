// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/CKRecordableTests.swift
// dependencies: [Coders/CKDecoder.swift, Coders/CKEncoder.swift, Extensions/UUID.swift, Protocols/CKRecordable.swift]

#if canImport(CloudKit)
import CloudKit
import Foundation
import Testing
@testable import Composition

private struct Note: CKRecordable, Equatable {

    let id: UUID
    var text: String
}

private struct Page: CKRecordable, Equatable {

    let id: Int
    var text: String
}

@Suite struct CKRecordableTests {

    @Test func roundTripsAnIntegerIdentifier() throws {
        let record: CKRecord = CKRecord(recordType: "Page")
        try CKEncoder().encode(Page(id: 7, text: "Hello"), to: record)
        #expect(try CKDecoder().decode(Page.self, from: record) == Page(id: 7, text: "Hello"))
    }

    @Test func roundTripsAUUIDIdentifierThroughItsDescription() throws {
        let note: Note = Note(id: .timestamp, text: "Hello")
        let record: CKRecord = CKRecord(recordType: "Note")
        try CKEncoder().encode(note, to: record)
        #expect(Note.ID(note.id.description) == note.id)
        #expect(try CKDecoder().decode(Note.self, from: record) == note)
    }
}
#endif
