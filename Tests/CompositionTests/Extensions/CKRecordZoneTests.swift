// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecordZoneTests.swift
// dependencies: [Extensions/CKRecordZone.swift]

#if canImport(CloudKit)
import CloudKit
import Testing
@testable import Composition

@Suite struct CKRecordZoneTests {

    @Test func defaultZoneIsACustomZoneOfTheCurrentUser() {
        #expect(CKRecordZone.ID.defaultZone.zoneName == "DefaultZone")
        #expect(CKRecordZone.ID.defaultZone.ownerName == CKCurrentUserDefaultName)
    }
}
#endif
