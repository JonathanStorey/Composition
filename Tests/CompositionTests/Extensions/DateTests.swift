// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/DateTests.swift
// dependencies: [Extensions/Date.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct DateTests {

    @Test func initTimestampReadsKnownValue() throws {
        let uuid: UUID = try #require(UUID(uuidString: "018BCFE5-6800-7000-8000-000000000000"))
        let date: Date = try #require(Date(timestamp: uuid))
        #expect(date == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func initTimestampReadsSubMillisecondFraction() throws {
        let uuid: UUID = try #require(UUID(uuidString: "018BCFE5-6800-7800-8000-000000000000"))
        let date: Date = try #require(Date(timestamp: uuid))
        #expect(abs(date.timeIntervalSince1970 - 1_700_000_000.0005) < 0.000_000_5)
    }

    @Test func initTimestampRejectsNonVersion7UUID() {
        #expect(Date(timestamp: UUID()) == nil)
    }

    @Test func relativeDescriptionDescribesPastAndFuture() {
        let past: String = Date().addingTimeInterval(-130).relativeDescription
        let future: String = Date().addingTimeInterval(130).relativeDescription
        #expect(!past.isEmpty)
        #expect(past != future)
        if Locale.current.language.languageCode == .english {
            #expect(past == "2 minutes ago")
            #expect(future == "in 2 minutes")
        }
    }
}
#endif
