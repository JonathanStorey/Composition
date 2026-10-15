// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecordTests.swift
// dependencies: [Extensions/CKRecord.swift]

#if canImport(CloudKit)
import CloudKit
import Testing
@testable import Composition

private struct Pair<First, Second> {}

@Suite struct CKRecordTests {

    @Test func replacesRunsOfSymbolsInTheRecordType() {
        #expect(CKRecord.recordType(of: Pair<Int, [String]>.self) == "Pair_Int_Array_String")
        #expect(CKRecord.recordType(of: Int.self) == "Int")
    }
}
#endif
