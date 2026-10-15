// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKDecoder.swift
// dependencies: [Coders/CodingNode.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// Decodes values from the fields of CloudKit records, the way `JSONDecoder` decodes them from JSON.
public struct CKDecoder: Sendable {

    /// Creates a decoder.
    public init() {}

    /// Decodes a value of the type from the record's fields, skipping assets, locations and references.
    public func decode<T: Decodable>(_ type: T.Type, from record: CKRecord) throws -> T {
        let fields: [String: CodingNode] = record.allKeys().reduce(into: [:]) { fields, key in fields[key] = record[key].flatMap { CodingNode(field: $0) } }
        return try NodeDecoder.decode(type, from: .keyed(fields), at: [])
    }
}

/// Reads a value from a `CodingNode`, the way `JSONDecoder` reads JSON.
private struct NodeDecoder: Decoder {

    let codingPath: [any CodingKey]
    let node: CodingNode
    let userInfo: [CodingUserInfoKey: Any] = [:]

    /// Reads the value from the node, natively when CloudKit keeps its type and otherwise through its own `init(from:)`.
    static func decode<T: Decodable>(_ type: T.Type, from node: CodingNode, at path: [any CodingKey]) throws -> T {
        if let value: T = try node.native(T.self, at: path) { return value }
        return try T(from: NodeDecoder(codingPath: path, node: node))
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .keyed(let fields) = try node.parsed else { throw mismatch([String: Any].self) }
        return KeyedDecodingContainer(KeyedContainer(decoder: self, fields: fields))
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleContainer(decoder: self, node: node)
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        switch try node.parsed {
        case .list(let items): UnkeyedContainer(decoder: self, items: items)
        case .null: UnkeyedContainer(decoder: self, items: [])  // an empty list keeps no field
        default: throw mismatch([Any].self)
        }
    }

    /// The error for a container the node doesn't hold.
    private func mismatch(_ type: Any.Type) -> DecodingError {
        let context: DecodingError.Context = DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but found \(node).")
        return node == .null ? DecodingError.valueNotFound(type, context) : DecodingError.typeMismatch(type, context)
    }
}

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    let decoder: NodeDecoder
    let fields: [String: CodingNode]

    var allKeys: [Key] { fields.keys.compactMap(Key.init(stringValue:)) }

    var codingPath: [any CodingKey] { decoder.codingPath }

    func contains(_ key: Key) -> Bool {
        fields[key.stringValue] != nil
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try take(type, key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try take(type, key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try take(type, key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try take(type, key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try take(type, key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try take(type, key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try take(type, key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try take(type, key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try take(type, key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try take(type, key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try take(type, key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try take(type, key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try take(type, key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try take(type, key) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try take(type, key) }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        try decodeNil(forKey: key) ? nil : take(type, key)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        (fields[key.stringValue] ?? .null) == .null
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        try NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        NodeDecoder(codingPath: codingPath + [CodingNode.Key.superKey], node: fields[CodingNode.Key.superKey.stringValue] ?? .null)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null)
    }

    /// Reads the value under the key from its field.
    private func take<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T {
        let path: [any CodingKey] = codingPath + [key]
        if let node: CodingNode = fields[key.stringValue] { return try NodeDecoder.decode(type, from: node, at: path) }
        do { return try NodeDecoder.decode(type, from: .null, at: path) }  // a missing field still reads as an empty list or nil
        catch { throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "The record has no \(key.stringValue) field.")) }
    }
}

private struct SingleContainer: SingleValueDecodingContainer {

    let decoder: NodeDecoder
    let node: CodingNode

    var codingPath: [any CodingKey] { decoder.codingPath }

    func decode(_ type: Bool.Type) throws -> Bool { try take(type) }
    func decode(_ type: Double.Type) throws -> Double { try take(type) }
    func decode(_ type: Float.Type) throws -> Float { try take(type) }
    func decode(_ type: Int.Type) throws -> Int { try take(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try take(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try take(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try take(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try take(type) }
    func decode(_ type: String.Type) throws -> String { try take(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try take(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try take(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try take(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try take(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try take(type) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try take(type) }

    func decodeNil() -> Bool {
        node == .null
    }

    /// Reads the value from the container's node.
    private func take<T: Decodable>(_ type: T.Type) throws -> T {
        try NodeDecoder.decode(type, from: node, at: codingPath)
    }
}

private struct UnkeyedContainer: UnkeyedDecodingContainer {

    let decoder: NodeDecoder
    let items: [CodingNode]
    var currentIndex: Int = 0

    var codingPath: [any CodingKey] { decoder.codingPath }

    var count: Int? { items.count }

    var isAtEnd: Bool { currentIndex >= items.count }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try take(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try take(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try take(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try take(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try take(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try take(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try take(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try take(type) }
    mutating func decode(_ type: String.Type) throws -> String { try take(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try take(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try take(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try take(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try take(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try take(type) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try take(type) }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd, items[currentIndex] == .null else { return false }
        currentIndex += 1
        return true
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try next(type) { try $0.container(keyedBy: type) }
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try next([Any].self) { try $0.unkeyedContainer() }
    }

    mutating func superDecoder() throws -> any Decoder {
        try next((any Decoder).self) { $0 }
    }

    /// Reads the next item with a decoder for it, moving past it only when reading succeeds.
    private mutating func next<V>(_ type: Any.Type, _ read: (NodeDecoder) throws -> V) throws -> V {
        let path: [any CodingKey] = codingPath + [CodingNode.Key(intValue: currentIndex)]
        guard !isAtEnd else { throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: path, debugDescription: "The list has no more items.")) }
        let value: V = try read(NodeDecoder(codingPath: path, node: items[currentIndex]))
        currentIndex += 1
        return value
    }

    /// Reads the next item as a value of the type.
    private mutating func take<T: Decodable>(_ type: T.Type) throws -> T {
        try next(type) { try NodeDecoder.decode(type, from: $0.node, at: $0.codingPath) }
    }
}
#endif
