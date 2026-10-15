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

private enum Color: String, Encodable {

    case blue
    case red
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

private struct Palette: Digestible, Encodable {

    let colors: Set<Color>
    let counts: [Color: Int]
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
        ["x": x, "y": y].digest(into: &digester)
    }
}

@Suite struct DigestibleTests {

    @Test func adjacentStringsDoNotCollide() {
        #expect(["ab", "c"].checksum() != ["a", "bc"].checksum())
    }

    @Test func arrayMatchesPython() {
        #expect(["a", "b"].checksum().uuidString.lowercased() == "7b2e031d-5505-515a-acf1-22e60aa6140d")
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
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).checksum().uuidString.lowercased() == "f1e96d31-845d-5da6-a963-1cc43cd7388a")
    }

    @Test func decimalMatchesPythonNormalizedString() throws {
        let decimal: Decimal = try #require(Decimal(string: "1.50"))
        #expect(decimal.checksum().uuidString.lowercased() == "f8ff5fef-f6d2-5b11-813c-03f54a003b39")
    }

    @Test func decomposedStringMatchesPythonBytes() {
        #expect("caf\u{E9}".checksum().uuidString.lowercased() == "6ffb5c84-cebb-5cc1-8672-bd35f1d7bc5f")
        #expect("cafe\u{301}".checksum().uuidString.lowercased() == "9436dc42-b661-515d-8aca-c0937c55ad59")
    }

    @Test func dictionaryMatchesPythonSortedPairs() {
        var dictionary: [String: Int] = ["b": 2]
        dictionary["a"] = 1
        #expect(dictionary.checksum().uuidString.lowercased() == "3175c854-b778-5487-aec9-2a298e68e460")
    }

    @Test func digesterFinalizesInEmptyNamespace() {
        var digester: Digester = Digester(namespace: "")
        digester.combine("abc")
        #expect(digester.finalize().uuidString.lowercased() == "7aaad436-a797-53b0-974c-a71690ef7706")
    }

    @Test func doubleNaNPayloadsMatchStandardNaN() {
        #expect(Double(bitPattern: 0xFFF8_0000_0000_0001).checksum().uuidString.lowercased() == "7d669e35-d1ac-550f-9989-346921304b4a")
        #expect(Double(bitPattern: 0xFFF8_0000_0000_0001).checksum() == Double.nan.checksum())
    }

    @Test func doubleNegativeZeroMatchesZero() {
        #expect((-0.0).checksum().uuidString.lowercased() == "e8f434da-b64a-51ec-b2c1-e27619e59902")
        #expect((-0.0).checksum() == 0.0.checksum())
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

    @Test func encodableUnorderedCollectionsOfNonDigestibleValuesMatchPython() {
        #expect(Palette(colors: [.red, .blue], counts: [.red: 2, .blue: 1]).checksum().uuidString.lowercased() == "0d86daf9-fd13-56e3-aeb6-f3cd47f97d83")
    }

    @Test func intMatchesPython() {
        #expect(1.checksum().uuidString.lowercased() == "fa6c604e-934e-500f-8f25-c5912a22c47d")
    }

    @Test func namespaceSurvivesRename() {
        #expect(Vector(x: 1, y: 2).checksum(namespace: "Point") == Point(x: 1, y: 2).checksum())
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.checksum() != String?.some("").checksum())
    }

    @Test func nilMatchesPython() {
        #expect(String?.none.checksum().uuidString.lowercased() == "f5976f16-7fd1-5d59-8a6d-8e238a320320")
    }

    @Test func optionalArrayMatchesPython() {
        let values: [String?] = [nil, "a"]
        #expect(values.checksum().uuidString.lowercased() == "28e9195e-7cbc-543b-984e-c02055eb18ee")
    }

    @Test func optionalPositionChangesChecksum() {
        let first: [String?] = [nil, "x"]
        let second: [String?] = ["x", nil]
        #expect(first.checksum() != second.checksum())
    }

    @Test func setMatchesPythonSortedDigests() {
        #expect(Set(["b", "a"]).checksum().uuidString.lowercased() == "888a75fa-b664-57c9-8fa9-60c4aec3c4c9")
    }

    @Test func someMatchesPython() {
        #expect(String?.some("abc").checksum().uuidString.lowercased() == "346d2d34-1577-533f-afd2-be148522bcdc")
    }

    @Test func stringMatchesPython() {
        #expect("abc".checksum().uuidString.lowercased() == "346d2d34-1577-533f-afd2-be148522bcdc")
    }
}
#endif
