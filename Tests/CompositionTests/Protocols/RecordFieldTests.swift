// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordFieldTests.swift
// dependencies: [Protocols/RecordCodable.swift, Protocols/RecordField.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation
import Testing
@testable import Composition

@Suite struct RecordFieldTests {

    @Test func listsUseThePluralOfTheirElementsField() throws {
        let record: CKRecord = CKRecord(recordType: "Values")
        ["Dune", "Emma"].encode(to: record)
        [3, 4].encode(to: record)
        #expect(record["strings"] as? [String] == ["Dune", "Emma"])
        #expect(try [String](from: record) == ["Dune", "Emma"])
        #expect(try [Int](from: record) == [3, 4])
    }

    @Test func nativeValuesRoundTripThroughTheirOwnFields() throws {
        let date: Date = Date(timeIntervalSince1970: 1_000)
        let record: CKRecord = CKRecord(recordType: "Values")
        true.encode(to: record)
        Data([1, 2]).encode(to: record)
        date.encode(to: record)
        2.5.encode(to: record)
        7.encode(to: record)
        "Dune".encode(to: record)
        #expect(record.allKeys().sorted() == ["boolean", "data", "date", "double", "integer", "string"])
        #expect(try Bool(from: record))
        #expect(try Data(from: record) == Data([1, 2]))
        #expect(try Date(from: record) == date)
        #expect(try Double(from: record) == 2.5)
        #expect(try Int(from: record) == 7)
        #expect(try String(from: record) == "Dune")
    }

    @Test func nativeValueThrowsWhenItsFieldIsEmpty() {
        #expect(throws: DecodingError.self) { try String(from: CKRecord(recordType: "Values")) }
    }
}
#endif
