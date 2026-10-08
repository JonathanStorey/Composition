#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Item: Timestamped {

    let timestamp: UUID
}

@Suite struct TimestampedTests {

    @Test func dateIsNilForNonVersion7Timestamp() {
        #expect(Item(timestamp: UUID()).date == nil)
    }

    @Test func dateReadsEmbeddedTime() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.25)
        let item = Item(timestamp: try #require(UUID(timestamp: date)))
        let decoded = try #require(item.date)
        #expect(abs(decoded.timeIntervalSince(date)) < 0.000_001)
    }

    @Test func timestampsSortByCreationTime() throws {
        let earlier = Item(timestamp: try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_000))))
        let later = Item(timestamp: try #require(UUID(timestamp: Date(timeIntervalSince1970: 1_700_000_001))))
        #expect(earlier.timestamp.uuidString < later.timestamp.uuidString)
    }
}
#endif
