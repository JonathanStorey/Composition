// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/JSONDecoderTests.swift
// dependencies: [Extensions/JSONDecoder.swift, Extensions/JSONEncoder.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct JSONDecoderTests {

    @Test func decodeCompatibilityReadsNonFiniteNumbers() throws {
        let values = try JSONDecoder().decode([Double].self, from: Data("[NaN,Infinity,-Infinity]".utf8), compatibility: .python)
        #expect(values[0].isNaN)
        #expect(values[1] == .infinity)
        #expect(values[2] == -.infinity)
    }

    @Test func decodeCompatibilityReadsPythonDates() throws {
        let date = try JSONDecoder().decode(Date.self, from: Data("1700000000123456".utf8), compatibility: .python)
        #expect(date == Date(timeIntervalSince1970: 1_700_000_000.123456))
    }

    @Test func decodeCompatibilityRoundTripsEncodedValues() throws {
        let data = try JSONEncoder().encode(PythonSample.example, compatibility: .python)
        #expect(try JSONDecoder().decode(PythonSample.self, from: data, compatibility: .python) == PythonSample.example)
    }

    @Test func decodeCompatibilityRoundTripsJCSValues() throws {
        let data = try JSONEncoder().encode(PythonSample.example, compatibility: .jcs)
        #expect(try JSONDecoder().decode(PythonSample.self, from: data, compatibility: .jcs) == PythonSample.example)
    }
}
#endif
