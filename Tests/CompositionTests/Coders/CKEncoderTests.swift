// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKEncoderTests.swift
// dependencies: [Coders/CKEncoder.swift, Extensions/CKRecord.swift, Extensions/CKRecordZone.swift, Extensions/UUID.swift, Protocols/CKRecordable.swift, Protocols/RecordSource.swift]

#if canImport(CloudKit)
import CloudKit
import Foundation
import Testing
@testable import Composition

private struct Book: Codable, CKRecordable, Identifiable {

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
    var chapters: [Chapter] = []
}

private struct Chapter: Codable, CKRecordable, Identifiable {

    let id: UUID
    var title: String
    var paragraphs: [Paragraph] = []
}

private struct Paragraph: Codable, CKRecordable, Identifiable {

    let id: Int
    var text: String
}

private struct Settings: Codable, CKRecordable {

    var fontSize: Double = 14
}

private enum Theme: String, Codable, CKRecordable {

    case dark, light
}

private struct Box<Value: Codable>: Codable, CKRecordable {

    var value: Value
}

private struct Author: Codable, CKRecordable, Identifiable {

    let id: String
}

private struct Counter: Codable, CKRecordable, Identifiable {

    let id: String
    var count: UInt64 = .max
}

private struct Drafts: Codable, CKRecordable, Identifiable {

    let id: String
    var drafts: [Chapter]? = nil
}

private struct Nest: Codable, CKRecordable, Identifiable {

    let id: String
    var nested: [String: [Chapter]]
}

private struct Shelf: Codable, CKRecordable, Identifiable {

    let id: String
    var favorite: Author
}

private struct Tag: Codable, CustomStringConvertible, Hashable {

    let raw: Int

    var description: String { "#\(raw)" }
}

private struct Tagged: Codable, CKRecordable, Identifiable {

    let id: Tag
}

private struct Twins: Codable, CKRecordable, Identifiable {

    let id: String
    var first: [Chapter] = []
    var second: [Chapter] = []
}

private struct Badly: Codable, CKRecordable, Identifiable {

    enum CodingKeys: String, CodingKey {

        case id, name = "first name"
    }

    let id: String
    var name: String = ""
}

@Suite struct CKEncoderTests {

    @Test func encodesASingleValueToTheFieldNamedForItsKind() throws {
        let records: [CKRecord] = try CKEncoder().encode(Theme.dark, key: "theme")
        #expect(records[0].recordID.recordName == "Theme.theme")
        #expect(records[0]["string"] as? String == "dark")
    }

    @Test func encodesChildrenAsRecordsOwnedThroughParent() throws {
        let chapter: Chapter = Chapter(id: .timestamp, title: "One", paragraphs: [Paragraph(id: 1, text: "A"), Paragraph(id: 2, text: "B")])
        let book: Book = Book(id: .timestamp, chapters: [chapter])
        let records: [CKRecord] = try CKEncoder().encode(book)
        #expect(records.map(\.recordType) == ["Book", "Chapter", "Paragraph", "Paragraph"])
        #expect(records[0]["chapters"] == nil)
        #expect(records[1].recordID.recordName == "Chapter.\(chapter.id)")
        #expect(records[1].parent?.recordID == records[0].recordID)
        #expect(records[2].parent?.recordID == records[1].recordID)
        #expect(records[3].recordID.recordName == "Paragraph.2")
        #expect(records.allSatisfy { $0.recordID.zoneID.zoneName == "DefaultZone" })
    }

    @Test func encodesFieldsNativelyAndEverythingElseAsJSON() throws {
        let book: Book = Book(id: .timestamp)
        let record: CKRecord = try CKEncoder().encode(book)[0]
        #expect(record.recordID.recordName == "Book.\(book.id)")
        #expect(record["id"] == nil)
        #expect(record["title"] as? String == "Dune")
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

    @Test func listsDeletionsForRemovedChildrenAndTheirDescendants() throws {
        let kept: Chapter = Chapter(id: .timestamp, title: "Kept")
        let removed: Chapter = Chapter(id: .timestamp, title: "Removed", paragraphs: [Paragraph(id: 1, text: "A")])
        var book: Book = Book(id: .timestamp, chapters: [kept, removed])
        let saved: [CKRecord] = try CKEncoder().encode(book)
        book.chapters = [kept]
        let records: [CKRecord] = try CKEncoder().encode(book, updating: saved)
        let deleted: [CKRecord.ID] = CKEncoder().recordIDsToDelete(for: records, in: saved)
        #expect(Set(deleted.map(\.recordName)) == ["Chapter.\(removed.id)", "Paragraph.1"])
    }

    @Test func namesRecordsByKeyOrTypeWithoutIdentity() throws {
        #expect(try CKEncoder().encode(Settings(), key: "reader")[0].recordID.recordName == "Settings.reader")
        #expect(try CKEncoder().encode(Settings(), key: nil)[0].recordID.recordName == "Settings")
        #expect(try CKEncoder().encode(Box(value: 1), key: nil)[0].recordType == "Box_Int")
    }

    @Test func removesFieldsTheValueNoLongerHas() throws {
        var book: Book = Book(id: .timestamp, subtitle: "Part One")
        let saved: [CKRecord] = try CKEncoder().encode(book)
        book.subtitle = nil
        book.tags = []
        let record: CKRecord = try CKEncoder().encode(book, updating: saved)[0]
        #expect(record === saved[0])
        #expect(record["subtitle"] == nil)
        #expect(record["tags"] == nil)
    }

    @Test func throwsForShapesCloudKitCantKeep() {
        let chapter: Chapter = Chapter(id: .timestamp, title: "One")
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Shelf(id: "a", favorite: Author(id: "b"))) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Drafts(id: "a")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Nest(id: "a", nested: ["x": [chapter]])) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Counter(id: "a")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Twins(id: "a")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Book(id: .timestamp, chapters: [chapter, chapter])) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Badly(id: "a")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Author(id: "é")) }
        #expect(throws: EncodingError.self) { try CKEncoder().encode(Tagged(id: Tag(raw: 1))) }
    }
}
#endif
