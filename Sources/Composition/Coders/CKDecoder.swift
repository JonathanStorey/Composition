// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKDecoder.swift
// dependencies: [Coders/CodingNode.swift, Extensions/CKRecord.swift, Protocols/CKRecordable.swift, Protocols/ChildRecords.swift, Protocols/RecordSource.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// Decodes a value from its CloudKit record, reading its children from a source of records on hand.
public struct CKDecoder: Sendable {

    /// Creates a decoder.
    public init() {}

    /// Reads a value's fields from the record, with its identifier from the record name and its children from the source of the decode call, if any.
    static func fields<R: Decodable>(_ type: R.Type, from record: CKRecord) throws -> R {
        guard record.recordType == CKRecord.recordType(of: R.self) else { throw DecodingError.typeMismatch(R.self, DecodingError.Context(codingPath: [], debugDescription: "A \(record.recordType) record doesn't keep a \(R.self).")) }
        let fields: [String: CodingNode] = record.allKeys().reduce(into: [:]) { fields, key in fields[key] = record[key].flatMap { CodingNode(field: $0) } }  // assets, locations and references are skipped
        let identity: String? = R.self is any Identifiable.Type ? (try? record.recordID.key(for: R.self)) : nil
        let root: Root = Root(identity: identity, recordID: record.recordID, source: DecodingScope.current?.source)
        return try R(from: NodeDecoder(codingPath: [], node: .keyed(fields), root: root))
    }

    /// Reads an identifier back from the key in its record name, through `LosslessStringConvertible` when the type has it and its own `Decodable` otherwise.
    static func identity<ID: Decodable>(_ type: ID.Type, from key: String, at path: [any CodingKey]) throws -> ID {
        if let losslessType: any LosslessStringConvertible.Type = ID.self as? any LosslessStringConvertible.Type, let id: ID = losslessType.init(key) as? ID { return id }
        return try NodeDecoder.decode(ID.self, from: .string(key), at: path)
    }

    /// Decodes the value from its record, reading its children from the source, which it needs only when the value has children.
    public func decode<R: CKRecordable & Decodable>(_ type: R.Type, from record: CKRecord, source: (any RecordSource)? = nil) throws -> R {
        try DecodingScope.$current.withValue(DecodingScope(source: source)) { try R(from: record) }
    }
}

/// The source an outer decode call reads children from.
private final class DecodingScope: @unchecked Sendable {  // lives only inside the synchronous call that binds it

    let source: (any RecordSource)?

    init(source: (any RecordSource)?) {
        self.source = source
    }

    /// The source of the innermost decode call.
    @TaskLocal static var current: DecodingScope?
}

/// The record being decoded, which supplies its identifier and the children of its properties.
private final class Root {

    let identity: String?
    let recordID: CKRecord.ID
    let source: (any RecordSource)?
    private var childTypes: Set<CKRecord.RecordType> = []

    init(identity: String?, recordID: CKRecord.ID, source: (any RecordSource)?) {
        self.identity = identity
        self.recordID = recordID
        self.source = source
    }

    /// The children of the record in the source, oldest first, with unsaved ones last and the record name breaking ties.
    func children<C: ChildRecords>(_ type: C.Type, at path: [any CodingKey]) throws -> C {
        let recordType: CKRecord.RecordType = CKRecord.recordType(of: C.Element.self)
        guard childTypes.insert(recordType).inserted else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: path, debugDescription: "A record can hold only one property of \(recordType) children.")) }
        guard let source else { throw DecodingError.valueNotFound(C.self, DecodingError.Context(codingPath: path, debugDescription: "Reading children needs the records on hand. Pass a source to CKDecoder.")) }
        let records: [CKRecord] = source.children(of: recordID).filter { $0.recordType == recordType }.sorted { ($0.creationDate ?? .distantFuture, $0.recordID.recordName) < ($1.creationDate ?? .distantFuture, $1.recordID.recordName) }
        return C(try records.map { try C.Element(from: $0) })
    }
}

/// Reads a value from a `CodingNode`, the way `JSONDecoder` reads JSON.
private struct NodeDecoder: Decoder {

    let codingPath: [any CodingKey]
    let node: CodingNode
    let root: Root?  // set only for a record's own fields, where children and the identifier come from
    let userInfo: [CodingUserInfoKey: Any] = [:]

    /// Reads the value from the node, natively when CloudKit keeps its type and otherwise through its own `init(from:)`.
    static func decode<T: Decodable>(_ type: T.Type, from node: CodingNode, at path: [any CodingKey]) throws -> T {
        if T.self is any ChildRecords.Type { throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: path, debugDescription: "Children must be an array or set property of their parent record.")) }
        if let value: T = try node.native(T.self, at: path) { return value }
        return try T(from: NodeDecoder(codingPath: path, node: node, root: nil))
    }

    /// The node a single value reads from: at a record's root, whichever field is named after a kind or `value`.
    private var single: CodingNode {
        guard root != nil, case .keyed(let fields) = node else { return node }
        return CodingNode.rootFields.lazy.compactMap { fields[$0] }.first ?? .null
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .keyed(let fields) = try node.parsed else { throw mismatch([String: Any].self) }
        return KeyedDecodingContainer(KeyedContainer(decoder: self, fields: fields))
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleContainer(decoder: self, node: single)
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        switch try single.parsed {
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
        fields[key.stringValue] != nil || identity(for: key) != nil
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
        if T.self is any ChildRecords.Type { throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Children can't be optional. Use an array or set instead.")) }
        return try decodeNil(forKey: key) ? nil : take(type, key)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        identity(for: key) == nil && (fields[key.stringValue] ?? .null) == .null
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null, root: nil).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        try NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null, root: nil).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        NodeDecoder(codingPath: codingPath + [CodingNode.Key.superKey], node: fields[CodingNode.Key.superKey.stringValue] ?? .null, root: nil)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        NodeDecoder(codingPath: codingPath + [key], node: fields[key.stringValue] ?? .null, root: nil)
    }

    /// The key from the record name when the key is `id` and the record keeps no `id` field.
    private func identity(for key: Key) -> String? {
        key.stringValue == "id" && fields["id"] == nil ? decoder.root?.identity : nil
    }

    /// Reads the value under the key: children from the source, the identifier from the record name, and everything else from its field.
    private func take<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T {
        let path: [any CodingKey] = codingPath + [key]
        if let childType: any ChildRecords.Type = T.self as? any ChildRecords.Type, let root: Root = decoder.root { return try root.children(childType, at: path) as! T }
        if let node: CodingNode = fields[key.stringValue] { return try NodeDecoder.decode(type, from: node, at: path) }
        if let identity: String = identity(for: key) { return try CKDecoder.identity(type, from: identity, at: path) }
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
        let value: V = try read(NodeDecoder(codingPath: path, node: items[currentIndex], root: nil))
        currentIndex += 1
        return value
    }

    /// Reads the next item as a value of the type.
    private mutating func take<T: Decodable>(_ type: T.Type) throws -> T {
        try next(type) { try NodeDecoder.decode(type, from: $0.node, at: $0.codingPath) }
    }
}
#endif
