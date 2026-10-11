// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/UUIDTests.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift, Protocols/Digestible.swift]

import Testing
@testable import Composition

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

@Suite struct UUIDTests {

    @Test func comparableSortsTimestampsByCreationTime() throws {
        let earlier: UUID = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0001)))
        let later: UUID = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0004)))
        #expect(earlier < later)
        #expect(UUID.zero < UUID.max)
    }

    @Test func initTimestampEncodesSubMillisecondPrecision() throws {
        let uuid: UUID = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.000_500_1)))
        #expect(uuid.uuidString.hasPrefix("018BCFE5-6800-7800-"))
    }

    @Test func initTimestampRejectsDatesBefore1970() {
        #expect(UUID(timestamp: Date(timeIntervalSince1970: -1)) == nil)
    }

    @Test func initTimestampRoundTripsThroughDate() throws {
        let date: Date = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let uuid: UUID = try #require(UUID(timestamp: date))
        let decoded: Date = try #require(Date(timestamp: uuid))
        #expect(abs(decoded.timeIntervalSince(date)) < 0.000_000_5)
    }

    @Test func initTimestampSortsWithinOneMillisecond() throws {
        let earlier: UUID = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0001)))
        let later: UUID = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000.0004)))
        #expect(earlier.uuidString < later.uuidString)
    }

    @Test func maxHasEveryBitSet() {
        #expect(UUID.max.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        #expect(UUID.max != UUID.zero)
    }

    @Test func timestampEmbedsCurrentTime() throws {
        let before: Date = Date().addingTimeInterval(-0.001)
        let decoded: Date = try #require(Date(timestamp: UUID.timestamp))
        let after: Date = Date().addingTimeInterval(0.001)
        #expect((before...after).contains(decoded))
    }

    @Test func timestampIsUnique() {
        #expect(UUID.timestamp != UUID.timestamp)
    }

    @Test func timestampSetsVersionAndVariant() {
        let characters: [Character] = Array(UUID.timestamp.uuidString)
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
private struct Title: Digestible, Encodable {

    let name: String
}

extension UUIDTests {

    @Test func initDigestDiffersByValue() {
        #expect(UUID(digest: "Dune") != UUID(digest: "Emma"))
    }

    @Test func initDigestEncodesDatesAsMicroseconds() {
        #expect(UUID(digest: Date(timeIntervalSince1970: 1_700_000_000.123456)).uuidString == "F1E96D31-845D-5DA6-A963-1CC43CD7388A")
    }

    @Test func initDigestIgnoresKeyOrder() {
        var first: [String: Int] = ["a": 1]
        first["b"] = 2
        var second: [String: Int] = ["b": 2]
        second["a"] = 1
        #expect(UUID(digest: first) == UUID(digest: second))
    }

    @Test func initDigestMatchesChecksum() {
        #expect(UUID(digest: [1, 2]) == [1, 2].checksum())
        #expect(UUID(digest: Data("www.example.com".utf8)) == Data("www.example.com".utf8).checksum())
    }

    @Test func initDigestMatchesPythonForData() {
        #expect(UUID(digest: Data("www.example.com".utf8)).uuidString == "8D83D065-36E4-5D65-B346-87DDBF3EF18F")
    }

    @Test func initDigestMatchesPythonForDoubles() {
        #expect(UUID(digest: 1.0).uuidString == "DEC944BA-ECE6-585C-8A80-496028ACE62A")
    }

    @Test func initDigestMatchesPythonForEncodableStructs() {
        #expect(UUID(digest: Title(name: "Dune")).uuidString == "CFA5CB0E-4122-50B4-8C4D-C05CD0A93142")
    }

    @Test func initDigestMatchesPythonForStrings() {
        #expect(UUID(digest: "Dune").uuidString == "7A7AE168-3F14-5728-B79F-8565561432C4")
    }

    @Test func initDigestNamespaceOverridesTypeName() {
        #expect(UUID(digest: "Dune", namespace: "Book").uuidString == "7D8CB9F5-A6D7-5995-AF75-D2DF624BF643")
        #expect(UUID(digest: "Dune", namespace: "str") == UUID(digest: "Dune"))
    }

    @Test func initDigestSetsVersionAndVariant() {
        let characters: [Character] = Array(UUID(digest: "Dune").uuidString)
        #expect(characters[14] == "5")
        #expect("89AB".contains(characters[19]))
    }
}
#endif
