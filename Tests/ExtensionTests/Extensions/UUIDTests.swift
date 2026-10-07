import Foundation
import Testing
@testable import Extension

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
