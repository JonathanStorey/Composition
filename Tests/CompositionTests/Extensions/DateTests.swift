import Foundation
import Testing
@testable import Composition

@Suite struct DateTests {

    @Test func initTimestampRejectsNonVersion7UUID() {
        #expect(Date(timestamp: UUID()) == nil)
    }

    @Test func initTimestampReadsKnownValue() throws {
        let uuid = try #require(UUID(uuidString: "018BCFE5-6800-7000-8000-000000000000"))
        let date = try #require(Date(timestamp: uuid))
        #expect(date == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func initTimestampReadsSubMillisecondFraction() throws {
        let uuid = try #require(UUID(uuidString: "018BCFE5-6800-7800-8000-000000000000"))
        let date = try #require(Date(timestamp: uuid))
        #expect(abs(date.timeIntervalSince1970 - 1_700_000_000.0005) < 0.000_000_5)
    }

    @Test func relativeDescriptionDescribesPastAndFuture() {
        let past = Date().addingTimeInterval(-130).relativeDescription
        let future = Date().addingTimeInterval(130).relativeDescription
        #expect(!past.isEmpty)
        #expect(past != future)
        if Locale.current.language.languageCode == .english {
            #expect(past == "2 minutes ago")
            #expect(future == "in 2 minutes")
        }
    }
}
