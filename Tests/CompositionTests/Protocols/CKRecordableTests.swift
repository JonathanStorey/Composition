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

    @Test func namesTheRecordByAnIdentifierThatReadsBack() throws {
        let note: Note = Note(id: .timestamp, text: "Hello")
        let record: CKRecord = try CKEncoder().encode(note)
        #expect(record.recordID.recordName == "Note.\(note.id)")
        #expect(UUID(String(record.recordID.recordName.dropFirst(5))) == note.id)
        #expect(try CKDecoder().decode(Note.self, from: record) == note)
    }

    @Test func roundTripsAnIntegerIdentifier() throws {
        let record: CKRecord = try CKEncoder().encode(Page(id: 7, text: "Hello"))
        #expect(record.recordID.recordName == "Page.7")
        #expect(try CKDecoder().decode(Page.self, from: record) == Page(id: 7, text: "Hello"))
    }
}
#endif
