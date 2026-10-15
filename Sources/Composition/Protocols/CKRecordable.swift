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

    /// Creates the value from the record's fields with `CKDecoder`.
    init(from record: CKRecord) throws {
        self = try CKDecoder().decode(Self.self, from: record)
    }

    /// Writes the value into the record's fields with `CKEncoder`.
    func encode(to record: CKRecord) throws {
        try CKEncoder().encode(self, to: record)
    }
}
#endif
