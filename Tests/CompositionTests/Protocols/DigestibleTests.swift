#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Note: Digestible {

    let body: String
    let id: UUID
    let parentChecksum: Data?

    func digest(into digester: inout Digester) {
        digester.combine(id)
        digester.combine(parentChecksum)
        digester.combine(body)
    }
}

private extension Data {

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

@Suite struct DigestibleTests {

    @Test func adjacentStringsDoNotCollide() {
        #expect(["ab", "c"].checksum != ["a", "bc"].checksum)
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

    @Test func checksumIsStableForEqualValues() {
        let id = UUID()
        #expect(Note(body: "Draft", id: id, parentChecksum: nil).checksum == Note(body: "Draft", id: id, parentChecksum: nil).checksum)
    }

    @Test func checksumIsThirtyTwoBytes() {
        #expect("".checksum.count == 32)
    }

    @Test func dateMatchesItsTimeInterval() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.5)
        #expect(date.checksum == date.timeIntervalSince1970.checksum)
    }

    @Test func equivalentUnicodeFormsMatch() {
        #expect("\u{E9}".checksum == "e\u{301}".checksum)
    }

    @Test func intMatchesKnownVector() {
        #expect(1.checksum.hexString == "e1204f7fab020db18a0690d525c4bfebd7ffcd34d6242f3956bc9780d29ff38e")
    }

    @Test func nilDiffersFromEmptyValue() {
        #expect(String?.none.checksum != String?.some("").checksum)
    }

    @Test func stringMatchesKnownVector() {
        #expect("abc".checksum.hexString == "c3494ca1a2cf8eeb8a11ded316fb55b83c3bbbedb6313cd50415251e5d09e12f")
    }
}
#endif
