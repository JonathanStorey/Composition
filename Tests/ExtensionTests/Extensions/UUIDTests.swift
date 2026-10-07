import Foundation
import Testing
@testable import Extension

@Suite struct UUIDTests {

    @Test func initTimestampRejectsDatesBefore1970() {
        #expect(UUID(timestamp: Date(timeIntervalSince1970: -1)) == nil)
    }

    @Test func initTimestampRoundTripsThroughDate() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        let uuid = try #require(UUID(timestamp: date))
        let decoded = try #require(Date(timestamp: uuid))
        let reencoded = try #require(UUID(timestamp: decoded))
        #expect(abs(decoded.timeIntervalSince(date)) < 0.0005)
        #expect(reencoded.uuidString.prefix(13) == uuid.uuidString.prefix(13))
    }

    @Test func timeStampEmbedsCurrentTime() throws {
        let before = Date().addingTimeInterval(-0.001)
        let decoded = try #require(Date(timestamp: UUID.timeStamp))
        let after = Date().addingTimeInterval(0.001)
        #expect((before...after).contains(decoded))
    }

    @Test func timeStampIsUnique() {
        #expect(UUID.timeStamp != UUID.timeStamp)
    }

    @Test func timeStampSetsVersionAndVariant() {
        let characters = Array(UUID.timeStamp.uuidString)
        #expect(characters[14] == "7")
        #expect("89AB".contains(characters[19]))
    }

    @Test func timeStampSortsByCreationTime() throws {
        let earlier = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000)))
        let later = try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_001)))
        #expect(earlier.uuidString < later.uuidString)
    }
}
