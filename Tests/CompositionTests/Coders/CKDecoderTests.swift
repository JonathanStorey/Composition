// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKDecoderTests.swift
// dependencies: [Coders/CKDecoder.swift, Coders/CKEncoder.swift, Extensions/UUID.swift]

#if canImport(CloudKit)
import CloudKit
import Foundation
import Testing
@testable import Composition

private struct Book: Codable, Equatable {

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
}

@Suite struct CKDecoderTests {

    @Test func readsAMissingListAsEmpty() throws {
        let record: CKRecord = CKRecord(recordType: "Book")
        try CKEncoder().encode(Book(id: .timestamp), to: record)
        #expect(record["tags"] == nil)
        #expect(try CKDecoder().decode(Book.self, from: record).tags == [])
    }

    @Test func roundTripsEveryKindOfField() throws {
        let book: Book = Book(id: .timestamp, subtitle: "Part One", tags: ["classic"])
        let record: CKRecord = CKRecord(recordType: "Book")
        try CKEncoder().encode(book, to: record)
        #expect(try CKDecoder().decode(Book.self, from: record) == book)
    }

    @Test func throwsWhenTheRecordCantHoldTheValue() throws {
        let record: CKRecord = CKRecord(recordType: "Book")
        try CKEncoder().encode(Book(id: .timestamp), to: record)
        record["title"] = nil
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Book.self, from: record) }
        record["title"] = 7 as Int64
        #expect(throws: DecodingError.self) { try CKDecoder().decode(Book.self, from: record) }
        #expect(throws: DecodingError.self) { try CKDecoder().decode(String.self, from: record) }
    }
}
#endif
