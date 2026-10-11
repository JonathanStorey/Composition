// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DigestibleTests.swift
// dependencies: [Extensions/UUID.swift, Protocols/Digestible.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Book: Digestible, Encodable {

    let title: String
    let year: Int?
}

private enum Kind: String, Digestible, Encodable {

    case draft
}

private struct Line: Digestible, Encodable {

    let end: Point
    let start: Point
}

private struct Note: Digestible {

    let body: String
    let id: UUID
    let parentChecksum: UUID?

    func digest(into digester: inout Digester) {
        digester.combine(id)
        digester.combine(parentChecksum)
        digester.combine(body)
    }
}

private struct Point: Digestible, Encodable {

    let x: Int
    let y: Int
}

private struct Shelf: Digestible, Encodable {

    let tags: Set<String>
}

private struct Vector: Digestible {

    let x: Int
    let y: Int

    func digest(into digester: inout Digester) {
        digester.use(namespace: "Point")
        ["x": x, "y": y].digest(into: &digester)
    }
}

@Suite struct DigestibleTests {

    @Test func adjacentStringsDoNotCollide() {
        #expect(["ab", "c"].checksum() != ["a", "bc"].checksum())
    }

    @Test func arrayMatchesPython() {
        #expect(["a", "b"].checksum().uuidString.lowercased() == "237a0c21-426f-5a65-b17d-715c239bc1d9")
    }

    @Test func arrayOrderChangesChecksum() {
        #expect([1, 2].checksum() != [2, 1].checksum())
    }

    @Test func checksumChangesWhenParentChanges() {
        let id: UUID = UUID()
        let first: Note = Note(body: "Draft", id: id, parentChecksum: "A".checksum())
        let second: Note = Note(body: "Draft", id: id, parentChecksum: "B".checksum())
        #expect(first.checksum() != second.checksum())
    }

    @Test func checksumIsStableForEqualValues() {
        let id: UUID = UUID()
        #expect(Note(body: "Draft", id: id, parentChecksum: nil).checksum() == Note(body: "Draft", id: id, parentChecksum: nil).checksum())
    }

    @Test func checksumIsVersionFiveUUID() {
        #expect("abc".checksum().version == 5)
    }

    @Test func checksumSeparatesTypesWithEqualContent() {
        #expect(Point(x: 1, y: 2).checksum() != ["x": 1, "y": 2].checksum())
    }

    @Test func dateMatchesPythonMicroseconds() {
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).checksum().uuidString.lowercased() == "133057f3-94d7-5a17-8370-732243f5dcd2")
    }

    @Test func decimalMatchesPythonNormalizedString() throws {
        #expect(try #require(Decimal(string: "1.50")).checksum().uuidString.lowercased() == "f8ff5fef-f6d2-5b11-813c-03f54a003b39")
    }

    @Test func decomposedStringMatchesPythonBytes() {
        #expect("caf\u{E9}".checksum().uuidString.lowercased() == "f804c7d8-131b-5ea3-8015-aa18ab34eda6")
        #expect("cafe\u{301}".checksum().uuidString.lowercased() == "219f3f66-54ed-5d36-9611-23014584b46b")
    }

    @Test func dictionaryMatchesPythonSortedPairs() {
        var dictionary: [String: Int] = ["b": 2]
        dictionary["a"] = 1
        #expect(dictionary.checksum().uuidString.lowercased() == "93bb3ed0-b6a8-5145-8fc5-4cc5210e6002")
    }

    @Test func digesterFinalizesInNilNamespace() {
        var digester: Digester = Digester()
        digester.combine("abc")
        #expect(digester.finalize().uuidString.lowercased() == "a8cf195d-0d19-5d6f-a042-d4653dbc5d98")
    }

    @Test func encodableEnumMatchesPythonRawValue() {
        #expect(Kind.draft.checksum().uuidString.lowercased() == "fc3d2af7-f659-548b-800f-8c3dbeacebd3")
    }

    @Test func encodableNestedStructMatchesPython() {
        #expect(Line(end: Point(x: 1, y: 2), start: Point(x: 0, y: 0)).checksum().uuidString.lowercased() == "6f5c2a97-4bb9-5c61-8f29-299efbeb3ee5")
    }

    @Test func encodableNilPropertyIsLeftOut() {
        #expect(Book(title: "Dune", year: nil).checksum().uuidString.lowercased() == "a7313219-fe9b-5b8d-816c-8860925f185d")
        #expect(Book(title: "Dune", year: nil).checksum() != Book(title: "Dune", year: 1965).checksum())
    }

    @Test func encodableSetUsesSortedDigests() {
        #expect(Shelf(tags: ["b", "a"]).checksum().uuidString.lowercased() == "f58804b7-a55a-52fd-997e-acdbbe38fff1")
    }

    @Test func encodableStructMatchesPythonDictionary() {
        #expect(Point(x: 1, y: 2).checksum().uuidString.lowercased() == "31c4ce15-c77a-53b4-b9ba-07b3160f4e2d")
    }

    @Test func intMatchesPython() {
        #expect(1.checksum().uuidString.lowercased() == "4930d598-5c4b-5d4f-942d-c01ac82b3998")
    }

    @Test func namespaceSurvivesRename() {
        #expect(Vector(x: 1, y: 2).checksum() == Point(x: 1, y: 2).checksum())
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.checksum() != String?.some("").checksum())
    }

    @Test func nilMatchesPython() {
        #expect(String?.none.checksum().uuidString.lowercased() == "bd512a38-04a5-5880-8995-6c943b2888c8")
    }

    @Test func optionalArrayMatchesPython() {
        let values: [String?] = [nil, "a"]
        #expect(values.checksum().uuidString.lowercased() == "7534268b-d46f-58ae-ad70-c1142b3b0ab9")
    }

    @Test func optionalPositionChangesChecksum() {
        let first: [String?] = [nil, "x"]
        let second: [String?] = ["x", nil]
        #expect(first.checksum() != second.checksum())
    }

    @Test func setMatchesPythonSortedDigests() {
        #expect(Set(["b", "a"]).checksum().uuidString.lowercased() == "15a12e4e-43f4-5f65-a6d6-b3bca87fa078")
    }

    @Test func someMatchesPython() {
        #expect(String?.some("abc").checksum().uuidString.lowercased() == "9aa7c342-a84d-5d85-88f9-6e7b3c750f99")
    }

    @Test func stringMatchesPython() {
        #expect("abc".checksum().uuidString.lowercased() == "b0a3bad5-67e3-5474-ba39-f091c769cd7c")
    }
}
#endif
