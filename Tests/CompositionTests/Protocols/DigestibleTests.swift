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

private extension Data {

    /// The bytes as lowercase hexadecimal.
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

@Suite struct DigestibleTests {

    @Test func adjacentStringsDoNotCollide() {
        #expect(["ab", "c"].digest != ["a", "bc"].digest)
    }

    @Test func arrayMatchesPythonDigestOfDigests() {
        #expect(["a", "b"].digest.hex == "e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a")
    }

    @Test func arrayOrderChangesDigest() {
        #expect([1, 2].digest != [2, 1].digest)
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

    @Test func checksumIsVersionFiveUUIDMatchingPython() {
        #expect("abc".checksum().version == 5)
        #expect("abc".checksum().uuidString.lowercased() == "b0a3bad5-67e3-5474-ba39-f091c769cd7c")
        #expect(Point(x: 1, y: 2).checksum().uuidString.lowercased() == "31c4ce15-c77a-53b4-b9ba-07b3160f4e2d")
    }

    @Test func checksumSeparatesTypesWithEqualDigests() {
        #expect(Point(x: 1, y: 2).digest == ["x": 1, "y": 2].digest)
        #expect(Point(x: 1, y: 2).checksum() != ["x": 1, "y": 2].checksum())
    }

    @Test func dateMatchesPythonMicroseconds() {
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).digest.hex == "7319daf208645ce78f8795a741d5da8bb48f2cd01a7a55eedbd7d6539c6592c7")
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).digest == 1_700_000_000_123_456.digest)
    }

    @Test func decimalMatchesPythonNormalizedString() throws {
        #expect(try #require(Decimal(string: "1.50")).digest.hex == "9f29a130438b81170b92a42650f9a94291ecad60bd47af2a3886e75f7f728725")
        #expect(Decimal(100).digest == "100".digest)
    }

    @Test func decomposedStringMatchesPythonBytes() {
        #expect("caf\u{E9}".digest.hex == "850f7dc43910ff890f8879c0ed26fe697c93a067ad93a7d50f466a7028a9bf4e")
        #expect("cafe\u{301}".digest.hex == "81ef060bcd98adc7824eb5c1ada83c32491b16018e11e79f00ab9d09e04b015a")
    }

    @Test func dictionaryMatchesPythonSortedPairs() {
        var dictionary: [String: Int] = ["b": 2]
        dictionary["a"] = 1
        #expect(dictionary.digest.hex == "50d73636681fe21c1f907ba74a5d2157ad808c91057c78fc0ab57a9e0c6527f2")
    }

    @Test func digestIsThirtyTwoBytes() {
        #expect("".digest.count == 32)
    }

    @Test func encodableEnumMatchesRawValue() {
        #expect(Kind.draft.digest == "draft".digest)
    }

    @Test func encodableNestedStructMatchesDictionaryOfStructs() {
        let start: Point = Point(x: 0, y: 0)
        let end: Point = Point(x: 1, y: 2)
        #expect(Line(end: end, start: start).digest == ["end": end, "start": start].digest)
    }

    @Test func encodableNilPropertyIsLeftOut() {
        #expect(Book(title: "Dune", year: nil).digest == ["title": "Dune"].digest)
        #expect(Book(title: "Dune", year: nil).digest != Book(title: "Dune", year: 1965).digest)
    }

    @Test func encodableSetUsesSortedDigests() {
        #expect(Shelf(tags: ["b", "a"]).digest == ["tags": Set(["a", "b"])].digest)
    }

    @Test func encodableStructMatchesPythonDictionary() {
        #expect(Point(x: 1, y: 2).digest.hex == "f99c010e4c7f305fd562b60874896352e7fd49c214917c302b2d8e47e4dfac6b")
        #expect(Point(x: 1, y: 2).digest == ["x": 1, "y": 2].digest)
    }

    @Test func intMatchesKnownVector() {
        #expect(1.digest.hex == "cd2662154e6d76b2b2b92e70c0cac3ccf534f9b74eb5b89819ec509083d00a50")
    }

    @Test func namespaceIsVersionFiveUUIDOfTypeName() {
        #expect(String.namespace.uuidString.lowercased() == "f309902d-5749-51f6-8cc5-deec421aa994")
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.digest != String?.some("").digest)
    }

    @Test func nilIsZeroBlock() {
        #expect(String?.none.digest == Data(count: 32))
    }

    @Test func optionalArrayMatchesPython() {
        let values: [String?] = [nil, "a"]
        #expect(values.digest.hex == "8c374a53782642f7514d087d26a3e733f1b806009a03e04a43b288ef2fa9f9c0")
    }

    @Test func optionalPositionChangesDigest() {
        let first: [String?] = [nil, "x"]
        let second: [String?] = ["x", nil]
        #expect(first.digest != second.digest)
    }

    @Test func setMatchesPythonSortedDigests() {
        #expect(Set(["b", "a"]).digest.hex == "18d79cb747ea174c59f3a3b41768672526d56fecc58360a99d283d0f9b0a3cc0")
    }

    @Test func someMatchesWrappedValue() {
        #expect(String?.some("abc").digest == "abc".digest)
    }

    @Test func stringMatchesPythonSHA256() {
        #expect("abc".digest.hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
#endif
