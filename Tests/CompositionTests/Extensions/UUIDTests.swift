import Testing
@testable import Composition

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

@Suite struct UUIDTests {

    @Test func comparableSortsTimestampsByCreationTime() throws {
        let earlier = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0001)))
        let later = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0004)))
        #expect(earlier < later)
        #expect(UUID.zero < UUID.max)
    }

    @Test func initTimestampEncodesSubMillisecondPrecision() throws {
        let uuid = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.000_500_1)))
        #expect(uuid.uuidString.hasPrefix("018BCFE5-6800-7800-"))
    }

    @Test func initTimestampRejectsDatesBefore1970() {
        #expect(UUID(timestamp: Date(timeIntervalSince1970: -1)) == nil)
    }

    @Test func initTimestampRoundTripsThroughDate() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let uuid = try #require(UUID(timestamp: date))
        let decoded = try #require(Date(timestamp: uuid))
        #expect(abs(decoded.timeIntervalSince(date)) < 0.000_000_5)
    }

    @Test func initTimestampSortsWithinOneMillisecond() throws {
        let earlier = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0001)))
        let later = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0004)))
        #expect(earlier.uuidString < later.uuidString)
    }

    @Test func maxHasEveryBitSet() {
        #expect(UUID.max.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        #expect(UUID.max != UUID.zero)
    }

    @Test func timestampEmbedsCurrentTime() throws {
        let before = Date().addingTimeInterval(-0.001)
        let decoded = try #require(Date(timestamp: UUID.timestamp))
        let after = Date().addingTimeInterval(0.001)
        #expect((before...after).contains(decoded))
    }

    @Test func timestampIsUnique() {
        #expect(UUID.timestamp != UUID.timestamp)
    }

    @Test func timestampSetsVersionAndVariant() {
        let characters = Array(UUID.timestamp.uuidString)
        #expect(characters[14] == "7")
        #expect("89AB".contains(characters[19]))
    }

    @Test func versionIsNilOutsideRFC9562Variant() {
        #expect(UUID.max.version == nil)
        #expect(UUID.zero.version == nil)
    }

    @Test func versionReadsVersionNumber() throws {
        #expect(UUID().version == 4)
        #expect(UUID.timestamp.version == 7)
        #expect(try #require(UUID(uuidString: "2ED6657D-E927-568B-95E1-2665A8AEA6A2")).version == 5)
    }

    @Test func zeroHasEveryBitCleared() {
        #expect(UUID.zero.uuidString == "00000000-0000-0000-0000-000000000000")
        #expect(UUID.zero != UUID())
    }
}
#endif

// MARK: - CryptoKit + Foundation

#if canImport(CryptoKit) && canImport(Foundation)
extension UUIDTests {

    @Test func initHashDiffersByNamespace() throws {
        #expect(try UUID(hash: "Dune") != UUID(hash: "Dune", namespace: UUID(hash: "Book")))
        #expect(try UUID(hash: "Dune", namespace: UUID(hash: "Author")) != UUID(hash: "Dune", namespace: UUID(hash: "Book")))
    }

    @Test func initHashDiffersByValue() throws {
        #expect(try UUID(hash: "Dune") != UUID(hash: "Emma"))
    }

    @Test func initHashHashesDataBytesDirectly() throws {
        let data = Data("www.example.com".utf8)
        #expect(try UUID(hash: data).uuidString == "399FC331-BE2B-5B56-B676-D6F38DAE5AAA")
        #expect(try UUID(hash: data, namespace: UUID(hash: "Image")).uuidString == "B2FB507C-C942-58E2-AB1C-C6A61418C3FB")
    }

    @Test func initHashIgnoresKeyOrder() throws {
        var first = ["a": 1]
        first["b"] = 2
        var second = ["b": 2]
        second["a"] = 1
        #expect(try UUID(hash: first) == UUID(hash: second))
    }

    @Test func initHashMatchesPythonForStrings() throws {
        #expect(try UUID(hash: "Hello, World!").uuidString == "64DC4AC1-4A83-5B25-AABB-3603762EE2E3")
        #expect(try UUID(hash: "caf\u{E9}").uuidString == "5ACA2037-E489-53A0-8A86-3CAB62A1217C")
        #expect(try UUID(hash: "cafe\u{301}").uuidString == "7BF98B1B-D239-5B21-800B-BC2A5EAD565F")
    }

    @Test func initHashMatchesSortedJSON() throws {
        #expect(try UUID(hash: ["b": 2, "a": 1]).uuidString == "6FB42BB7-64C6-545B-BB52-552962F36259")
    }

    @Test func initHashSetsVersionAndVariant() throws {
        let characters = try Array(UUID(hash: "Dune").uuidString)
        #expect(characters[14] == "5")
        #expect("89AB".contains(characters[19]))
    }

    @Test func initHashUsesStandardNamespaces() throws {
        let dns = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        #expect(try UUID(hash: "www.example.com", namespace: dns).uuidString == "2ED6657D-E927-568B-95E1-2665A8AEA6A2")
    }

    @Test func initNameMatchesRFC9562Example() throws {
        let dns = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        #expect(UUID(name: Data("www.example.com".utf8), namespace: dns).uuidString == "2ED6657D-E927-568B-95E1-2665A8AEA6A2")
    }
}
#endif
