// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKEncoderTests.swift
// dependencies: [Coders/CKEncoder.swift, Extensions/UUID.swift]

#if canImport(CloudKit)
import CloudKit
import Foundation
import Testing
@testable import Composition

private struct Book: Codable {

    enum Genre: String, Codable {

        case fiction, poetry
    }

    struct Size: Codable {

        let height: Int
        let width: Int
    }

    let id: UUID
    var title: String = "Dune"
    var subtitle: String? = nil
    var pages: Int = 412
    var rating: Double = 4.5
    var isFavorite: Bool = true
    var published: Date = Date(timeIntervalSinceReferenceDate: 0)
    var cover: Data = Data([1, 2, 3])
    var link: URL = URL(string: "https://example.com/dune")!
    var tags: [String] = ["classic", "desert"]
    var genre: Genre = .fiction
    var size: Size = Size(height: 23, width: 15)
}

private struct Badly: Codable {

    enum CodingKeys: String, CodingKey {

        case id, name = "first name"
    }

    let id: String
    var name: String = ""
}

private struct Counter: Codable {

    let id: String
    var count: UInt64 = .max
}

@Suite struct CKEncoderTests {

    @Test func encodesFieldsNativelyAndEverythingElseAsJSON() throws {
        let book: Book = Book(id: .timestamp)
        let record: CKRecord = CKRecord(recordType: "Book")
        try CKEncoder().encode(book, to: record)
        #expect(record["id"] as? String == book.id.uuidString)
        #expect(record["title"] as? String == "Dune")
        #expect(record["subtitle"] == nil)
        #expect(record["pages"] as? Int64 == 412)
        #expect(record["rating"] as? Double == 4.5)
        #expect(record["isFavorite"] as? Bool == true)
        #expect(record["published"] as? Date == Date(timeIntervalSinceReferenceDate: 0))
        #expect(record["cover"] as? Data == Data([1, 2, 3]))
        #expect(record["link"] as? String == "https://example.com/dune")
        #expect(record["tags"] as? [String] == ["classic", "desert"])
        #expect(record["genre"] as? String == "fiction")
        #expect(record["size"] as? Data == Data(#"{"height":23,"width":15}"#.utf8))
    }

    @Test func leavesFieldsTheValueDoesntName() throws {
        let record: CKRecord = CKRecord(recordType: "Book")
        record["note"] = "kept"
        try CKEncoder().encode(Book(id: .timestamp, title: "Emma"), to: record)
        #expect(record["note"] as? String == "kept")
        #expect(record["title"] as? String == "Emma")
    }

    @Test func removesFieldsTheValueNoLongerHas() throws {
        var book: Book = Book(id: .timestamp, subtitle: "Part One")
        let record: CKRecord = CKRecord(recordType: "Book")
        try CKEncoder().encode(book, to: record)
        book.subtitle = nil
        book.tags = []
        try CKEncoder().encode(book, to: record)
        #expect(record["subtitle"] == nil)
        #expect(record["tags"] == nil)
        #expect(record["title"] as? String == "Dune")
    }

    @Test func throwsForValuesCloudKitCantKeep() {
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Badly(id: "a"), to: CKRecord(recordType: "Badly")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Counter(id: "a"), to: CKRecord(recordType: "Counter")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode("text", to: CKRecord(recordType: "Text")) }
    }
}
#endif
