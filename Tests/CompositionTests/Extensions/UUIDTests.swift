import Testing
@testable import Composition

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

@Suite struct UUIDTests {

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
}
#endif

// MARK: - CryptoKit + Foundation

#if canImport(CryptoKit) && canImport(Foundation)
extension UUIDTests {

    @Test func initHashDiffersByNamespace() throws {
        #expect(try UUID(hash: "Dune") != UUID(hash: "Dune", namespace: "Book"))
        #expect(try UUID(hash: "Dune", namespace: "Author") != UUID(hash: "Dune", namespace: "Book"))
    }

    @Test func initHashDiffersByValue() throws {
        #expect(try UUID(hash: "Dune") != UUID(hash: "Emma"))
    }

    @Test func initHashHashesDataBytesDirectly() throws {
        let data = Data("www.example.com".utf8)
        #expect(try UUID(hash: data).uuidString == "777E9788-7A2B-549A-8D98-0CCBD4AC0267")
        #expect(try UUID(hash: data, namespace: "Image").uuidString == "94C1F6AF-1EB4-591B-A2D4-8762230CA9C4")
    }

    @Test func initHashIgnoresKeyOrder() throws {
        var first = ["a": 1]
        first["b"] = 2
        var second = ["b": 2]
        second["a"] = 1
        #expect(try UUID(hash: first) == UUID(hash: second))
    }

    @Test func initHashMatchesSortedJSON() throws {
        #expect(try UUID(hash: ["b": 2, "a": 1]).uuidString == "19F08257-1CC3-5052-83AD-251F902C6CE7")
    }

    @Test func initHashSetsVersionAndVariant() throws {
        let characters = try Array(UUID(hash: "Dune").uuidString)
        #expect(characters[14] == "5")
        #expect("89AB".contains(characters[19]))
    }

    @Test func initNameMatchesRFC9562Example() throws {
        let dns = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        #expect(UUID(name: Data("www.example.com".utf8), namespace: dns).uuidString == "2ED6657D-E927-568B-95E1-2665A8AEA6A2")
    }
}
#endif
