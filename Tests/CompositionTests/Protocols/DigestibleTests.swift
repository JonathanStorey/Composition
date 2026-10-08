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
        #expect(["a", "b"].checksum.description == "abaa71505e04ae17be6779cbc6f3ef1db3efe1e9672cdc424e8b80c2419d32d4")
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

    @Test func checksumIsDigestible() {
        #expect("abc".checksum.checksum != "abc".checksum)
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

    @Test func dateMatchesItsTimeInterval() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.5)
        #expect(date.checksum == date.timeIntervalSince1970.checksum)
    }

    @Test func decomposedStringMatchesPythonBytes() {
        #expect("caf\u{E9}".checksum.description == "850f7dc43910ff890f8879c0ed26fe697c93a067ad93a7d50f466a7028a9bf4e")
        #expect("cafe\u{301}".checksum.description == "81ef060bcd98adc7824eb5c1ada83c32491b16018e11e79f00ab9d09e04b015a")
    }

    @Test func intMatchesKnownVector() {
        #expect(1.checksum.description == "cd2662154e6d76b2b2b92e70c0cac3ccf534f9b74eb5b89819ec509083d00a50")
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.checksum != String?.some("").checksum)
    }

    @Test func stringMatchesPythonSHA256() {
        #expect("abc".checksum.description == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
#endif
