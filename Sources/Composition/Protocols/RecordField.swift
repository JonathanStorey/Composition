// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordField.swift
// dependencies: [Protocols/RecordCodable.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// A value CloudKit keeps natively, written to the record field named after its kind, such as `string` for `String`, and in a list to the plural, such as `strings`.
public protocol RecordField: CKRecordValueProtocol {

    /// The name of the field that keeps a value of the type.
    static var field: String { get }
}

extension Array: RecordCodable where Element: RecordField {

    /// Creates the list from the plural of its element's field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: "\(Element.field)s")
    }

    /// Writes the list to the plural of its element's field.
    public func encode(to record: CKRecord) {
        record["\(Element.field)s"] = self
    }
}

extension Bool: RecordCodable, RecordField {

    /// The field that keeps a Boolean value.
    public static var field: String { "boolean" }

    /// Creates the value from the `boolean` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the value to the `boolean` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

extension Data: RecordCodable, RecordField {

    /// The field that keeps bytes.
    public static var field: String { "data" }

    /// Creates the bytes from the `data` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the bytes to the `data` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

extension Date: RecordCodable, RecordField {

    /// The field that keeps a date.
    public static var field: String { "date" }

    /// Creates the date from the `date` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the date to the `date` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

extension Double: RecordCodable, RecordField {

    /// The field that keeps a double.
    public static var field: String { "double" }

    /// Creates the value from the `double` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the value to the `double` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

extension Int: RecordCodable, RecordField {

    /// The field that keeps an integer.
    public static var field: String { "integer" }

    /// Creates the value from the `integer` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the value to the `integer` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

extension String: RecordCodable, RecordField {

    /// The field that keeps text.
    public static var field: String { "string" }

    /// Creates the text from the `string` field.
    public init(from record: CKRecord) throws {
        self = try record.value(in: Self.field)
    }

    /// Writes the text to the `string` field.
    public func encode(to record: CKRecord) {
        record[Self.field] = self
    }
}

fileprivate extension CKRecord {

    /// The value kept in the field, throwing when the field is empty or holds another type.
    func value<V>(in field: String) throws -> V {
        guard let value: V = self[field] as? V else { throw DecodingError.valueNotFound(V.self, DecodingError.Context(codingPath: [], debugDescription: "The record has no \(V.self) in its \(field) field.")) }
        return value
    }
}
#endif
