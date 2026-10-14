// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/CKRecordCodable.swift
// dependencies: []

#if canImport(CloudKit)
import CloudKit

/// A type that reads itself from and writes itself to the fields of a CloudKit record.
public protocol CKRecordCodable {

    /// Creates the value from the record's fields, throwing when they don't hold one.
    init(from record: CKRecord) throws

    /// Writes the value's fields into the record.
    func encode(to record: CKRecord) throws
}
#endif
