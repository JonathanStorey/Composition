// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/TimestampRepresentableTests.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift, Protocols/TimestampRepresentable.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct TimestampRepresentableTests {

    @Test func dateReadsTheEmbeddedTime() {
        let date: Date = Date(timeIntervalSince1970: 1_700_000_000)
        let uuid: UUID = UUID(timestamp: date)!
        #expect(abs(Date(timestamp: uuid)!.timeIntervalSince(date)) < 0.001)
    }

    @Test func uuidIsItselfWhenVersion7() {
        let uuid: UUID = .timestamp
        #expect(UUID(timestamp: uuid) == uuid)
    }

    @Test func uuidIsNilWhenNotVersion7() {
        #expect(UUID(timestamp: UUID()) == nil)
    }
}
#endif
