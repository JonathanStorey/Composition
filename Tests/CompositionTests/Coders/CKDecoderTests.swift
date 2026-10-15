// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKDecoderTests.swift
// dependencies: [Coders/CKDecoder.swift, Coders/CKEncoder.swift, Extensions/CKRecord.swift, Extensions/UUID.swift, Protocols/CKRecordable.swift, Protocols/RecordSource.swift]

#if canImport(CloudKit)
import CloudKit
import Foundation
import Testing
@testable import Composition

private struct Book: Codable, CKRecordable, Equatable, Identifiable {

    struct Size: Codable, Equatable {

        let height: Int
        let width: Int
    }

    let id: UUID
    var title: String = "Dune"
    var subtitle: String? = nil
    var pages: Int = 412
    var rating: Double = 4
    var isFavorite: Bool = true
    var published: Date = Date(timeIntervalSinceReferenceDate: 60)
    var cover: Data = Data([1, 2, 3])
    var link: URL = URL(string: "https://example.com/dune")!
    var tags: [String] = []
    var scores: [Int?] = [1, nil]
    var size: Size = Size(height: 23, width: 15)
    var chapters: [Chapter] = []
}

private struct Chapter: Codable, CKRecordable, Equatable, Identifiable {

    let id: UUID
    var title: String
    var notes: Set<Note> = []
}

private struct Note: Codable, CKRecordable, Hashable, Identifiable {

    let id: Int
    var text: String
}

private struct Tags: Codable, CKRecordable, Equatable {

    var values: [String]

    init(values: [String]) {
        self.values = values
    }

    init(from decoder: any Decoder) throws {
        values = try decoder.singleValueContainer().decode([String].self)
    }

    func encode(to encoder: any Encoder) throws {
        var container: any SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(values)
    }
}

private enum Theme: String, Codable, CKRecordable {

    case dark, light
}

@Suite struct CKDecoderTests {

    @Test func decodesASingleValueFromItsKindField() throws {
        let records: [CKRecord] = try CKEncoder().encode(Tags(values: ["a", "b"]), key: nil)
        #expect(records[0]["strings"] as? [String] == ["a", "b"])
        #expect(try CKDecoder().decode(Tags.self, from: records[0]) == Tags(values: ["a", "b"]))
        #expect(try CKDecoder().decode(Theme.self, from: CKEncoder().encode(Theme.light, key: "theme")[0]) == .light)
    }

    @Test func decodesChildrenInTheOrderTheyWereAdded() throws {
        let first: Chapter = Chapter(id: .timestamp, title: "One", notes: [Note(id: 1, text: "A"), Note(id: 2, text: "B")])
        let second: Chapter = Chapter(id: .timestamp, title: "Two")
        let book: Book = Book(id: .timestamp, chapters: [first, second])
        let records: [CKRecord] = try CKEncoder().encode(book)
        #expect(try CKDecoder().decode(Book.self, from: records[0], source: records.reversed()) == book)
    }

    @Test func roundTripsEveryKindOfField() throws {
        let book: Book = Book(id: .timestamp, subtitle: "Part One", tags: ["classic"])
        let records: [CKRecord] = try CKEncoder().encode(book)
        #expect(try CKDecoder().decode(Book.self, from: records[0], source: records) == book)
        #expect(try CKDecoder().decode(Book.self, from: CKEncoder().encode(Book(id: .timestamp))[0], source: []).tags == [])
    }

    @Test func throwsWhenTheRecordCantHoldTheValue() throws {
        let record: CKRecord = try CKEncoder().encode(Book(id: .timestamp))[0]
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Book.self, from: record) }
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Chapter.self, from: record, source: []) }
        record["title"] = nil
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Book.self, from: record, source: []) }
        let renamed: CKRecord = CKRecord(recordType: "Note", recordID: CKRecord.ID(recordName: "Other.1"))
        renamed["text"] = "A"
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Note.self, from: renamed) }
    }
}
#endif
