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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        #expect(try encoder.encode(PythonSample.example, compatibility: .python) == JSONEncoder().encode(PythonSample.example, compatibility: .python))
    }

    @Test func encodeCompatibilityMatchesPythonDumps() throws {
        let json = try String(decoding: JSONEncoder().encode(PythonSample.example, compatibility: .python), as: UTF8.self)
        #expect(json == #"{"count":7,"data":"AP9oaQ==","date":1700000000123456,"flag":true,"name":"Café/\n\t\"q\"\\\u0001","numbers":[1.0,0.1,1e+16,1000000000000000.0,1e-05,0.0001,-0.0,123.456,5e-324,1.7976931348623157e+308,-2.5e-07,100.0,1234567890123456.8],"price":1.5,"tags":{"Z":0,"a":1,"ab":null,"b":2,"é":3}}"#)
    }

    @Test func encodeCompatibilityWritesTopLevelValues() throws {
        #expect(try String(decoding: JSONEncoder().encode(1.0, compatibility: .python), as: UTF8.self) == "1.0")
        #expect(try String(decoding: JSONEncoder().encode(Double.nan, compatibility: .python), as: UTF8.self) == "NaN")
        #expect(try String(decoding: JSONEncoder().encode([String](), compatibility: .python), as: UTF8.self) == "[]")
    }
}
#endif
