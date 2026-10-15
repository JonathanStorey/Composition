// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CodingNode.swift
// dependencies: []

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

/// A value in the shape `Codable` writes it, which the record coders map onto CloudKit fields and, when CloudKit has no matching type, JSON.
enum CodingNode: Equatable, Sendable {

    case bool(Bool)
    case data(Data)
    case date(Date)
    case double(Double)
    case integer(Int64)
    case keyed([String: CodingNode])
    case list([CodingNode])
    case null
    case string(String)

    /// Captures a value CloudKit keeps natively, or returns nil so the value encodes itself, throwing for an integer outside Int64.
    init?(native value: Any, at path: [any CodingKey]) throws {
        switch value {
        case let value as Bool: self = .bool(value)
        case let value as String: self = .string(value)
        case let value as Date: self = .date(value)
        case let value as Data: self = .data(value)
        case let value as URL: self = .string(value.absoluteString)
        case let value as any BinaryInteger:
            guard let integer: Int64 = Int64(exactly: value) else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: path, debugDescription: "\(value) doesn't fit in the 64-bit integer CloudKit keeps.")) }
            self = .integer(integer)
        case let value as any BinaryFloatingPoint: self = .double(Double(value))
        case let value as any LosslessStringConvertible: self = .string(value.description)
        default: return nil
        }
    }

    /// The Boolean the node holds.
    var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } }

    /// The bytes the node holds.
    var dataValue: Data? { if case .data(let value) = self { value } else { nil } }

    /// The date the node holds.
    var dateValue: Date? { if case .date(let value) = self { value } else { nil } }

    /// The double the node holds.
    var doubleValue: Double? { if case .double(let value) = self { value } else { nil } }

    /// The integer the node holds.
    var integerValue: Int64? { if case .integer(let value) = self { value } else { nil } }

    /// The node itself, or the node its bytes hold as JSON, which is how fields CloudKit can't keep natively are stored.
    var parsed: CodingNode {
        get throws {
            guard case .data(let json) = self else { return self }
            return try JSONDecoder().decode(CodingNode.self, from: json)
        }
    }

    /// The string the node holds.
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }

    /// A Boolean value indicating whether the nodes hold the same value, counting a whole double and the equal integer as one number, as CloudKit's numbers do.
    func isSame(as other: CodingNode) -> Bool {
        switch (self, other) {
        case (.integer(let integer), .double(let double)), (.double(let double), .integer(let integer)): Double(exactly: integer) == double
        case (.list(let items), .list(let others)): items.count == others.count && zip(items, others).allSatisfy { $0.isSame(as: $1) }
        default: self == other
        }
    }

    /// The node encoded as JSON with sorted keys, so equal values give equal bytes.
    func json() throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// The node as a value of the type when the type is one CloudKit keeps natively, or nil so the type decodes itself.
    func native<T>(_ type: T.Type, at path: [any CodingKey]) throws -> T? {
        let value: Any?
        switch type {
        case is Bool.Type: value = boolValue ?? integerValue.flatMap { [0, 1].contains($0) ? $0 == 1 : nil }  // CloudKit keeps Booleans as 0 and 1
        case is String.Type: value = stringValue
        case is Date.Type: value = dateValue ?? (doubleValue ?? integerValue.map(Double.init)).map(Date.init(timeIntervalSinceReferenceDate:))  // JSON keeps dates as seconds
        case is Data.Type: value = dataValue ?? stringValue.flatMap { Data(base64Encoded: $0) }  // JSON keeps bytes as Base64
        case is URL.Type: value = stringValue.flatMap(URL.init(string:))
        case let integerType as any BinaryInteger.Type: value = integerValue.flatMap { integerType.init(exactly: $0) }
        case let floatingType as any BinaryFloatingPoint.Type: value = (doubleValue ?? integerValue.map(Double.init)).map { floatingType.init($0) }  // whole doubles can read back as integers
        case let losslessType as any LosslessStringConvertible.Type: value = stringValue.flatMap { losslessType.init($0) }
        default: return nil
        }
        if let value: T = value as? T { return value }
        let context: DecodingError.Context = DecodingError.Context(codingPath: path, debugDescription: "Expected \(T.self) but found \(self).")
        throw self == .null ? DecodingError.valueNotFound(T.self, context) : DecodingError.typeMismatch(T.self, context)
    }
}

extension CodingNode: Codable {

    /// Reads the node from JSON.
    init(from decoder: any Decoder) throws {
        let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value: Bool = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value: Int64 = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value: Double = try? container.decode(Double.self) { self = .double(value) }
        else if let value: String = try? container.decode(String.self) { self = .string(value) }
        else if let value: [CodingNode] = try? container.decode([CodingNode].self) { self = .list(value) }
        else { self = .keyed(try container.decode([String: CodingNode].self)) }
    }

    /// Writes the node as JSON, with dates as seconds since 2001 and bytes as Base64.
    func encode(to encoder: any Encoder) throws {
        var container: any SingleValueEncodingContainer = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .data(let value): try container.encode(value.base64EncodedString())
        case .date(let value): try container.encode(value.timeIntervalSinceReferenceDate)
        case .double(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .keyed(let value): try container.encode(value)
        case .list(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .string(let value): try container.encode(value)
        }
    }
}

extension CodingNode {

    /// A coding key for a list position or a superclass.
    struct Key: CodingKey {

        let intValue: Int?
        let stringValue: String

        init(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }

        init(stringValue: String) {
            self.intValue = nil
            self.stringValue = stringValue
        }

        /// The key a superclass encodes under.
        static let superKey: Key = Key(stringValue: "super")
    }
}

#endif

// MARK: - CloudKit + Foundation

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

extension CodingNode {

    /// Reads a field CloudKit returned, keeping Booleans as the integers CloudKit stores, or returns nil for assets, locations and references.
    init?(field value: Any) {
        switch value {
        case let value as String: self = .string(value)
        case let value as Date: self = .date(value)
        case let value as Data: self = .data(value)
        case let value as Int64: self = .integer(value)
        case let value as Double: self = .double(value)
        case let value as Bool: self = .integer(value ? 1 : 0)
        case let value as [String]: self = .list(value.map(CodingNode.string))
        case let value as [Date]: self = .list(value.map(CodingNode.date))
        case let value as [Data]: self = .list(value.map(CodingNode.data))
        case let value as [Int64]: self = .list(value.map(CodingNode.integer))
        case let value as [Double]: self = .list(value.map(CodingNode.double))
        case let value as [Bool]: self = .list(value.map { .integer($0 ? 1 : 0) })
        default: return nil
        }
    }

    /// The names of the fields a value written at a record's root can use, one per kind and plural, then `value` for JSON.
    static let rootFields: [String] = ["boolean", "data", "date", "double", "integer", "string"].flatMap { [$0, "\($0)s"] } + ["value"]

    /// The items as one of CloudKit's native list types, or nil when they are empty, mix kinds or nest.
    static func nativeList(_ items: [CodingNode]) -> (any CKRecordValueProtocol)? {
        func all<V: CKRecordValueProtocol>(_ value: KeyPath<CodingNode, V?>) -> [V]? {
            let values: [V] = items.compactMap { $0[keyPath: value] }
            return values.count == items.count && !items.isEmpty ? values : nil
        }
        let lists: [(any CKRecordValueProtocol)?] = [all(\.boolValue), all(\.dataValue), all(\.dateValue), all(\.doubleValue), all(\.integerValue), all(\.stringValue)]
        return lists.lazy.compactMap { $0 }.first
    }

    /// The field a value written at a record's root goes to: its kind, the plural of its items' kind for a native list, or `value` for JSON.
    var rootField: String {
        switch self {
        case .bool: "boolean"
        case .data: "data"
        case .date: "date"
        case .double: "double"
        case .integer: "integer"
        case .string: "string"
        case .list(let items) where CodingNode.nativeList(items) != nil: "\(items[0].rootField)s"
        case .keyed, .list, .null: "value"
        }
    }

    /// The node as the value to store in a field: native when CloudKit has the type, JSON bytes when it doesn't, and nil when there is nothing to store.
    func field() throws -> (any CKRecordValueProtocol)? {
        switch self {
        case .bool(let value): return value
        case .data(let value): return value
        case .date(let value): return value
        case .double(let value): return value
        case .integer(let value): return value
        case .string(let value): return value
        case .null: return nil
        case .list(let items) where items.isEmpty: return nil  // an empty list reads back from a missing field
        case .list(let items): return try CodingNode.nativeList(items) ?? json()
        case .keyed: return try json()
        }
    }
}
#endif
