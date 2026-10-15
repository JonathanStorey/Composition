// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecordTests.swift
// dependencies: [Extensions/CKRecord.swift]

#if canImport(CloudKit)
import CloudKit
import Testing
@testable import Composition

private struct Pair<First, Second> {}

@Suite struct CKRecordTests {

    @Test func namesARecordByTypeAndKey() throws {
        #expect(try CKRecord.ID(for: Int.self, key: "42").recordName == "Int.42")
        #expect(try CKRecord.ID(for: Int.self, key: nil).recordName == "Int")
        #expect(throws: EncodingError.self) { try CKRecord.ID(for: Int.self, key: "café") }
    }

    @Test func readsTheKeyBackFromTheRecordName() throws {
        #expect(try CKRecord.ID(recordName: "Int.4.2").key(for: Int.self) == "4.2")
        #expect(try CKRecord.ID(recordName: "Int").key(for: Int.self) == nil)
        #expect(throws: DecodingError.self) { try CKRecord.ID(recordName: "String.42").key(for: Int.self) }
    }

    @Test func replacesRunsOfSymbolsInTheRecordType() {
        #expect(CKRecord.recordType(of: Pair<Int, [String]>.self) == "Pair_Int_Array_String")
        #expect(CKRecord.recordType(of: Int.self) == "Int")
    }
}
#endif
