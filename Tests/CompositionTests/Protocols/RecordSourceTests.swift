// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordSourceTests.swift
// dependencies: [Protocols/RecordSource.swift]

#if canImport(CloudKit)
import CloudKit
import Testing
@testable import Composition

@Suite struct RecordSourceTests {

    @Test func arrayFindsChildrenAndRecordsByIdentifier() {
        let parent: CKRecord = CKRecord(recordType: "Book", recordID: CKRecord.ID(recordName: "Book.1"))
        let child: CKRecord = CKRecord(recordType: "Chapter", recordID: CKRecord.ID(recordName: "Chapter.1"))
        child.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
        let records: [CKRecord] = [parent, child]
        #expect(records.children(of: parent.recordID) == [child])
        #expect(records.children(of: child.recordID).isEmpty)
        #expect(records.record(with: CKRecord.ID(recordName: "Chapter.1")) === child)
        #expect(records.record(with: CKRecord.ID(recordName: "Chapter.2")) == nil)
    }
}
#endif
