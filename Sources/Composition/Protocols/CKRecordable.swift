// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/CKRecordable.swift
// dependencies: [Coders/CKDecoder.swift, Coders/CKEncoder.swift]

#if canImport(CloudKit)
import CloudKit

/// A type that reads itself from and writes itself to the fields of a CloudKit record.
public protocol CKRecordable {

    /// Creates the value from the record's fields, throwing when they don't hold one.
    init(from record: CKRecord) throws

    /// Writes the value's fields into the record.
    func encode(to record: CKRecord) throws
}

public extension CKRecordable where Self: Codable {

    /// Creates the value from the record's fields and name, reading children from the source given to `CKDecoder`.
    init(from record: CKRecord) throws {
        self = try CKDecoder.fields(Self.self, from: record)
    }

    /// Writes the value's own fields into the record, removing any it no longer has, and hands its children to `CKEncoder`.
    func encode(to record: CKRecord) throws {
        try CKEncoder.fields(self, to: record)
    }
}
#endif
