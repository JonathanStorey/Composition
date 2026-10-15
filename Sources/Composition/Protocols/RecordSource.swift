// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordSource.swift
// dependencies: []

#if canImport(CloudKit)
import CloudKit

/// A place the record coders find records already on hand, without fetching: children to decode, and records to update in place.
public protocol RecordSource {

    /// The records whose parent is the record with the identifier.
    func children(of id: CKRecord.ID) -> [CKRecord]

    /// The record with the identifier, or nil when the source doesn't hold it.
    func record(with id: CKRecord.ID) -> CKRecord?
}

extension Array: RecordSource where Element == CKRecord {

    /// The records in the array whose parent is the record with the identifier.
    public func children(of id: CKRecord.ID) -> [CKRecord] {
        filter { $0.parent?.recordID == id }
    }

    /// The first record in the array with the identifier.
    public func record(with id: CKRecord.ID) -> CKRecord? {
        first { $0.recordID == id }
    }
}
#endif
