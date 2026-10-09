// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DigestibleTests.swift
// dependencies: [Protocols/Digestible.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Note: Digestible {

    let body: String
    let id: UUID
    let parentChecksum: Checksum?

    func digest(into digester: inout Digester) {
        digester.combine(id)
        digester.combine(parentChecksum)
        digester.combine(body)
    }
}

@Suite struct DigestibleTests {

    @Test func adjacentStringsDoNotCollide() {
        #expect(["ab", "c"].checksum != ["a", "bc"].checksum)
    }

    @Test func arrayMatchesPythonChecksumOfChecksums() {
        #expect(["a", "b"].checksum.description == "e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a")
    }

    @Test func arrayOrderChangesChecksum() {
        #expect([1, 2].checksum != [2, 1].checksum)
    }

    @Test func checksumChangesWhenParentChanges() {
        let id = UUID()
        let first = Note(body: "Draft", id: id, parentChecksum: "A".checksum)
        let second = Note(body: "Draft", id: id, parentChecksum: "B".checksum)
        #expect(first.checksum != second.checksum)
    }

    @Test func checksumIsItsOwnChecksum() {
        let checksum = "abc".checksum
        #expect(checksum.checksum == checksum)
        #expect(String?.some("abc").checksum.checksum == checksum)
    }

    @Test func checksumIsStableForEqualValues() {
        let id = UUID()
        #expect(Note(body: "Draft", id: id, parentChecksum: nil).checksum == Note(body: "Draft", id: id, parentChecksum: nil).checksum)
    }

    @Test func checksumIsThirtyTwoBytes() {
        #expect("".checksum.bytes.count == 32)
    }

    @Test func checksumRoundTripsThroughCodable() throws {
        let checksum = "abc".checksum
        #expect(try JSONDecoder().decode(Checksum.self, from: JSONEncoder().encode(checksum)) == checksum)
    }

    @Test func dateMatchesPythonMicroseconds() {
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).checksum.description == "7319daf208645ce78f8795a741d5da8bb48f2cd01a7a55eedbd7d6539c6592c7")
        #expect(Date(timeIntervalSince1970: 1_700_000_000.123456).checksum == 1_700_000_000_123_456.checksum)
    }

    @Test func decimalMatchesPythonNormalizedString() throws {
        #expect(try #require(Decimal(string: "1.50")).checksum.description == "9f29a130438b81170b92a42650f9a94291ecad60bd47af2a3886e75f7f728725")
        #expect(Decimal(100).checksum == "100".checksum)
    }

    @Test func decomposedStringMatchesPythonBytes() {
        #expect("caf\u{E9}".checksum.description == "850f7dc43910ff890f8879c0ed26fe697c93a067ad93a7d50f466a7028a9bf4e")
        #expect("cafe\u{301}".checksum.description == "81ef060bcd98adc7824eb5c1ada83c32491b16018e11e79f00ab9d09e04b015a")
    }

    @Test func dictionaryMatchesPythonSortedPairs() {
        var dictionary = ["b": 2]
        dictionary["a"] = 1
        #expect(dictionary.checksum.description == "50d73636681fe21c1f907ba74a5d2157ad808c91057c78fc0ab57a9e0c6527f2")
    }

    @Test func intMatchesKnownVector() {
        #expect(1.checksum.description == "cd2662154e6d76b2b2b92e70c0cac3ccf534f9b74eb5b89819ec509083d00a50")
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.checksum != String?.some("").checksum)
    }

    @Test func nilIsZeroBlock() {
        #expect(String?.none.checksum.bytes == Data(count: 32))
    }

    @Test func optionalArrayMatchesPython() {
        let values: [String?] = [nil, "a"]
        #expect(values.checksum.description == "8c374a53782642f7514d087d26a3e733f1b806009a03e04a43b288ef2fa9f9c0")
    }

    @Test func optionalPositionChangesChecksum() {
        let first: [String?] = [nil, "x"]
        let second: [String?] = ["x", nil]
        #expect(first.checksum != second.checksum)
    }

    @Test func setMatchesPythonSortedDigests() {
        #expect(Set(["b", "a"]).checksum.description == "18d79cb747ea174c59f3a3b41768672526d56fecc58360a99d283d0f9b0a3cc0")
    }

    @Test func someMatchesWrappedValue() {
        #expect(String?.some("abc").checksum == "abc".checksum)
    }

    @Test func stringMatchesPythonSHA256() {
        #expect("abc".checksum.description == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
#endif
