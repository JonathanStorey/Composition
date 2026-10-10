// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/JSONEncoderTests.swift
// dependencies: [Extensions/JSONEncoder.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

struct PythonSample: Codable, Equatable {

    let count: Int
    let data: Data
    let date: Date
    let flag: Bool
    let name: String
    let note: String?
    let numbers: [Double]
    let price: Decimal
    let tags: [String: Int?]

    static let example = PythonSample(count: 7, data: Data([0x00, 0xFF, 0x68, 0x69]), date: Date(timeIntervalSince1970: 1_700_000_000.123456), flag: true, name: "Caf\u{E9}/\n\t\"q\"\\\u{1}", note: nil, numbers: [1.0, 0.1, 1e16, 1e15, 1e-5, 0.0001, -0.0, 123.456, 5e-324, 1.7976931348623157e308, -2.5e-7, 100.0, 1234567890123456.7], price: Decimal(string: "1.50") ?? 0, tags: ["b": 2, "a": 1, "\u{E9}": 3, "Z": 0, "ab": nil])
}

@Suite struct JSONEncoderTests {

    @Test func encodeCompatibilityIgnoresEncoderSettings() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        #expect(try encoder.encode(PythonSample.example, compatibility: .python) == JSONEncoder().encode(PythonSample.example, compatibility: .python))
    }

    @Test func encodeCompatibilityMatchesJavaScriptCanonicalization() throws {
        let json: String = try String(decoding: JSONEncoder().encode(PythonSample.example, compatibility: .jcs), as: UTF8.self)
        #expect(json == #"{"count":7,"data":"AP9oaQ==","date":1700000000123456,"flag":true,"name":"Café/\n\t\"q\"\\\u0001","numbers":[1,0.1,10000000000000000,1000000000000000,0.00001,0.0001,0,123.456,5e-324,1.7976931348623157e+308,-2.5e-7,100,1234567890123456.8],"price":1.5,"tags":{"Z":0,"a":1,"ab":null,"b":2,"é":3}}"#)
    }

    @Test func encodeCompatibilityMatchesPythonDumps() throws {
        let json: String = try String(decoding: JSONEncoder().encode(PythonSample.example, compatibility: .python), as: UTF8.self)
        #expect(json == #"{"count":7,"data":"AP9oaQ==","date":1700000000123456,"flag":true,"name":"Café/\n\t\"q\"\\\u0001","numbers":[1.0,0.1,1e+16,1000000000000000.0,1e-05,0.0001,-0.0,123.456,5e-324,1.7976931348623157e+308,-2.5e-07,100.0,1234567890123456.8],"price":1.5,"tags":{"Z":0,"a":1,"ab":null,"b":2,"é":3}}"#)
    }

    @Test func encodeCompatibilityRejectsNonFiniteNumbersForJCS() {
        #expect(throws: EncodingError.self) { try JSONEncoder().encode(Double.nan, compatibility: .jcs) }
        #expect(throws: EncodingError.self) { try JSONEncoder().encode([-Double.infinity], compatibility: .jcs) }
    }

    @Test func encodeCompatibilitySortsJCSKeysByUTF16() throws {
        #expect(try String(decoding: JSONEncoder().encode(["\u{FB01}": 1, "\u{1F600}": 2], compatibility: .jcs), as: UTF8.self) == "{\"\u{1F600}\":2,\"\u{FB01}\":1}")
        #expect(try String(decoding: JSONEncoder().encode(["\u{FB01}": 1, "\u{1F600}": 2], compatibility: .python), as: UTF8.self) == "{\"\u{FB01}\":1,\"\u{1F600}\":2}")
    }

    @Test func encodeCompatibilityWritesJCSNumbers() throws {
        #expect(try String(decoding: JSONEncoder().encode([1e21, 1e20, 1e-7, 0.000001], compatibility: .jcs), as: UTF8.self) == "[1e+21,100000000000000000000,1e-7,0.000001]")
        #expect(try String(decoding: JSONEncoder().encode(9_007_199_254_740_993, compatibility: .jcs), as: UTF8.self) == "9007199254740992")
    }

    @Test func encodeCompatibilityWritesTopLevelValues() throws {
        #expect(try String(decoding: JSONEncoder().encode(1.0, compatibility: .python), as: UTF8.self) == "1.0")
        #expect(try String(decoding: JSONEncoder().encode(Double.nan, compatibility: .python), as: UTF8.self) == "NaN")
        #expect(try String(decoding: JSONEncoder().encode([String](), compatibility: .python), as: UTF8.self) == "[]")
    }
}
#endif
