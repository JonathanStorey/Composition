// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordCodable.swift
// dependencies: []

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// A type that reads and writes itself as the fields of a CloudKit record, like `Codable`, leaving the record's type, name and zone to whoever creates it.
public protocol RecordCodable {

    /// Creates the value from the record's fields, like `Decodable`'s `init(from:)`, throwing when they don't hold one.
    init(from record: CKRecord) throws

    /// Writes the value's fields into the record, like `Encodable`'s `encode(to:)`, leaving its name, zone and server fields as they are.
    func encode(to record: CKRecord) throws
}

public extension RecordCodable where Self: Codable {

    /// Creates the value from the JSON kept in the record's `value` field.
    init(from record: CKRecord) throws {
        guard let data: Data = record["value"] as? Data else { throw DecodingError.valueNotFound(Self.self, DecodingError.Context(codingPath: [], debugDescription: "The record has no value field.")) }
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    /// Writes the value as JSON into the record's `value` field.
    func encode(to record: CKRecord) throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        record["value"] = try encoder.encode(self)
    }
}
#endif
