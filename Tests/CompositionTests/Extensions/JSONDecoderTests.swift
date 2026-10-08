#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct JSONDecoderTests {

    @Test func decodeCompatibilityReadsPythonDates() throws {
        let date = try JSONDecoder().decode(Date.self, from: Data("1700000000123456".utf8), compatibility: .python)
        #expect(date == Date(timeIntervalSince1970: 1_700_000_000.123456))
    }

    @Test func decodeCompatibilityRoundTripsEncodedValues() throws {
        let data = try JSONEncoder().encode(PythonSample.example, compatibility: .python)
        #expect(try JSONDecoder().decode(PythonSample.self, from: data, compatibility: .python) == PythonSample.example)
    }
}
#endif
