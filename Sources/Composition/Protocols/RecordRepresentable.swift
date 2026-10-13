// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordRepresentable.swift
// dependencies: []

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// A type that syncs as the fields of a CloudKit record, which the engine creates, names and places in a zone, so the value only reads and writes its own fields.
public protocol RecordRepresentable {

    /// Creates the value from the record's fields, like `Decodable`'s `init(from:)`, throwing when they don't hold one.
    init(from record: CKRecord) throws

    /// Writes the value's fields into the record, like `Encodable`'s `encode(to:)`, leaving its name, zone and server fields as they are.
    func encode(to record: CKRecord) throws
}

public extension RecordRepresentable {

    /// The CloudKit record type named after the type without its module, with nested and generic names joined by underscores, as `Library_Book` for `MyApp.Library.Book`, and a collection or optional named after its element.
    static var recordType: String {
        let reflected: String = String(reflecting: Self.self)
        assert(!reflected.contains("("), "\(reflected) is private or local, so its name changes between builds and can't name a CloudKit record type.")
        let name: String = recordTypeName(reflected[...])
        assert(name.first?.isLetter == true && name.utf8.count <= 255, "The record type \"\(name)\" for \(reflected) must start with a letter and fit in 255 characters.")
        return name
    }

    /// A new record holding the value's fields, of the type, named by the id and placed in the zone, which defaults to the zone `SyncedStorage` uses.
    func record(type recordType: String = Self.recordType, id recordName: String, zone zoneName: String = "Composition") throws -> CKRecord {
        let record: CKRecord = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordName, zoneID: CKRecordZone.ID(zoneName: zoneName)))
        try encode(to: record)
        return record
    }
}

public extension RecordRepresentable where Self: Codable {

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

public extension RecordRepresentable where Self: Identifiable {

    /// A new record holding the value's fields, of the type, named by the value's `id` and placed in the zone, so values with the same `id` in the same zone are the same record.
    func record(type recordType: String = Self.recordType, zone zoneName: String = "Composition") throws -> CKRecord {
        try record(type: recordType, id: String(describing: id), zone: zoneName)
    }
}

/// The reflected type name with each module dropped, nested and generic names joined by underscores, and `Optional`, `Array`, `ContiguousArray` and `Set` replaced by their element.
func recordTypeName(_ reflected: Substring) -> String {
    for container: String in ["Swift.Optional<", "Swift.Array<", "Swift.ContiguousArray<", "Swift.Set<"] where reflected.hasPrefix(container) && reflected.hasSuffix(">") {
        return recordTypeName(reflected.dropFirst(container.count).dropLast())
    }
    let paths: [Substring] = reflected.split { "<>, ".contains($0) }
    return paths.map { $0.split(separator: ".").dropFirst().joined(separator: "_") }.joined(separator: "_").filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
}
#endif
