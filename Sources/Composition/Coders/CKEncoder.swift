// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKEncoder.swift
// dependencies: [Coders/CKDecoder.swift, Coders/CodingNode.swift, Extensions/CKRecord.swift, Extensions/CKRecordZone.swift, Protocols/CKRecordable.swift, Protocols/ChildRecords.swift, Protocols/RecordSource.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// Encodes a value into CloudKit records: one for the value and one for each child, linked by `parent`.
public struct CKEncoder: Sendable {

    /// Creates an encoder.
    public init() {}

    /// Writes a value's own fields into the record, handing its children to the encode call that owns the record, if any.
    static func fields<R: Encodable>(_ value: R, to record: CKRecord) throws {
        guard record.recordType == CKRecord.recordType(of: R.self) else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "A \(record.recordType) record can't keep a \(R.self).")) }
        let scope: EncodingScope? = EncodingScope.current.flatMap { $0.recordID == record.recordID ? $0 : nil }  // only the call that created this record collects its children
        let slot: Slot = Slot()
        try value.encode(to: NodeEncoder(children: { try scope?.add($0, at: $1) }, codingPath: [], slot: slot))
        var fields: [String: CodingNode] = switch slot.node {
        case .keyed(let fields): fields
        case .null: [:]
        case let node: [node.rootField: node]  // a single value goes to the field named after its kind
        }
        if let id: String = (value as? any Identifiable).map({ String(describing: $0.id) }), (try? record.recordID.key(for: R.self)) == id { fields["id"] = nil }  // the name already holds it
        try record.apply(fields)
    }

    /// Encodes the value and its children into the zone, updating the records the source holds, and returns the value's record followed by its descendants.
    public func encode<R: CKRecordable & Encodable & Identifiable>(_ value: R, in zoneID: CKRecordZone.ID = .defaultZone, updating source: (any RecordSource)? = nil) throws -> [CKRecord] where R.ID: CustomStringConvertible & Decodable {
        try Tree(source: source, zoneID: zoneID).records(for: value, key: Tree.key(for: value.id), parent: nil)
    }

    /// Encodes a value without identity under the key, or under its record type alone when the key is nil, and returns its record followed by its descendants.
    public func encode<R: CKRecordable & Encodable>(_ value: R, key: String?, in zoneID: CKRecordZone.ID = .defaultZone, updating source: (any RecordSource)? = nil) throws -> [CKRecord] {
        try Tree(source: source, zoneID: zoneID).records(for: value, key: key, parent: nil)
    }

    /// The descendants of the first record that the source holds but the records no longer include, to delete in the same save.
    public func recordIDsToDelete(for records: [CKRecord], in source: some RecordSource) -> [CKRecord.ID] {
        guard let root: CKRecord = records.first else { return [] }
        let kept: Set<CKRecord.ID> = Set(records.map(\.recordID))
        var pending: [CKRecord.ID] = [root.recordID]
        var removed: [CKRecord.ID] = []
        while let id: CKRecord.ID = pending.popLast() {
            for child in source.children(of: id) {
                if !kept.contains(child.recordID) { removed.append(child.recordID) }
                pending.append(child.recordID)  // a removed child's own children go too
            }
        }
        return removed
    }
}

/// One encode call: the zone its records go in and the source whose records it updates.
private struct Tree {

    let source: (any RecordSource)?
    let zoneID: CKRecordZone.ID

    /// The key that names an identifier's record, throwing when the identifier can't be read back from it.
    static func key<ID: CustomStringConvertible & Decodable & Equatable>(for id: ID) throws -> String {
        let key: String = id.description
        guard (try? CKDecoder.identity(ID.self, from: key, at: [])) == id else { throw EncodingError.invalidValue(id, EncodingError.Context(codingPath: [], debugDescription: "\(ID.self) \(key) can't be read back from its description, which names its record.")) }
        return key
    }

    /// Encodes the value into its record, reusing the source's copy when it has one, followed by the records of its children.
    func records<R: CKRecordable & Encodable>(for value: R, key: String?, parent: CKRecord.ID?) throws -> [CKRecord] {
        let recordID: CKRecord.ID = try CKRecord.ID(for: R.self, key: key, zoneID: zoneID)
        let record: CKRecord = source?.record(with: recordID) ?? CKRecord(recordType: CKRecord.recordType(of: R.self), recordID: recordID)
        if record.parent?.recordID != parent { record.parent = parent.map { CKRecord.Reference(recordID: $0, action: .none) } }  // ownership only: no server-side cascade
        let scope: EncodingScope = EncodingScope(recordID: recordID, tree: self)
        try EncodingScope.$current.withValue(scope) { try value.encode(to: record) }
        return try [record] + scope.childRecords()
    }
}

/// The record an encode call is writing, collecting the child collections its fields hand off.
private final class EncodingScope: @unchecked Sendable {  // lives only inside the synchronous call that binds it

    let recordID: CKRecord.ID
    let tree: Tree
    private var childTypes: Set<CKRecord.RecordType> = []
    private var children: [() throws -> [CKRecord]] = []

    init(recordID: CKRecord.ID, tree: Tree) {
        self.recordID = recordID
        self.tree = tree
    }

    /// The record being written by the innermost encode call.
    @TaskLocal static var current: EncodingScope?

    /// Queues the children for encoding once their parent's fields are written, throwing when another property already holds their type.
    func add<C: ChildRecords>(_ children: C, at path: [any CodingKey]) throws {
        let recordType: CKRecord.RecordType = CKRecord.recordType(of: C.Element.self)
        guard childTypes.insert(recordType).inserted else { throw EncodingError.invalidValue(children, EncodingError.Context(codingPath: path, debugDescription: "A record can hold only one property of \(recordType) children, since their records can't say which property they belong to.")) }
        guard Set(children.map(\.id)).count == children.count else { throw EncodingError.invalidValue(children, EncodingError.Context(codingPath: path, debugDescription: "Two \(recordType) children share an identifier, and so a record.")) }
        self.children.append { [recordID, tree] in try children.flatMap { try tree.records(for: $0, key: Tree.key(for: $0.id), parent: recordID) } }
    }

    /// The records of every queued child and their descendants, in property order.
    func childRecords() throws -> [CKRecord] {
        try children.flatMap { try $0() }
    }
}

/// A node being built, which containers fill in place.
private final class Slot {

    var keyed: [String: Slot]?
    var list: [Slot]?
    var value: CodingNode?

    /// The finished node.
    var node: CodingNode {
        if let keyed { .keyed(keyed.mapValues(\.node)) } else if let list { .list(list.map(\.node)) } else { value ?? .null }
    }
}

/// Captures a value as a `CodingNode`, the way `JSONEncoder` captures JSON.
private struct NodeEncoder: Encoder {

    let children: ((any ChildRecords, [any CodingKey]) throws -> Void)?  // set only for a record's own fields, where children may appear
    let codingPath: [any CodingKey]
    let slot: Slot
    let userInfo: [CodingUserInfoKey: Any] = [:]

    /// Writes the value into the slot, natively when CloudKit keeps its type and otherwise as whatever its own `encode(to:)` writes.
    static func encode<T: Encodable>(_ value: T, into slot: Slot, at path: [any CodingKey]) throws {
        if value is any ChildRecords { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: path, debugDescription: "Children must be an array or set property of their parent record.")) }
        if value is any CKRecordable & Identifiable { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: path, debugDescription: "\(T.self) keeps its own record, so hold it in an array or set property of its parent.")) }
        if let node: CodingNode = try CodingNode(native: value, at: path) { slot.value = node } else { try value.encode(to: NodeEncoder(children: nil, codingPath: path, slot: slot)) }
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if slot.keyed == nil { slot.keyed = [:] }
        return KeyedEncodingContainer(KeyedContainer(encoder: self))
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleContainer(encoder: self)
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        if slot.list == nil { slot.list = [] }
        return UnkeyedContainer(encoder: self)
    }
}

private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    mutating func encode(_ value: Bool, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Int, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: String, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { try put(value, key) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { try put(value, key) }
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws { try put(value, key) }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if T.self is any ChildRecords.Type { throw EncodingError.invalidValue(value as Any, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Children can't be optional. Use an empty array or set instead.")) }
        if let value { try put(value, key) }  // nil writes nothing, which removes the field
    }

    mutating func encodeNil(forKey key: Key) throws {
        slot(for: key).value = .null
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        NodeEncoder(children: nil, codingPath: codingPath + [key], slot: slot(for: key)).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        NodeEncoder(children: nil, codingPath: codingPath + [key], slot: slot(for: key)).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        NodeEncoder(children: nil, codingPath: codingPath + [CodingNode.Key.superKey], slot: slot(for: CodingNode.Key.superKey.stringValue))
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        NodeEncoder(children: nil, codingPath: codingPath + [key], slot: slot(for: key))
    }

    /// Writes the value under the key, handing a record's child collections off instead.
    private func put<T: Encodable>(_ value: T, _ key: Key) throws {
        if let children: any ChildRecords = value as? any ChildRecords, let collect = encoder.children { return try collect(children, codingPath + [key]) }
        try NodeEncoder.encode(value, into: slot(for: key), at: codingPath + [key])
    }

    /// A new slot under the key.
    private func slot(for key: Key) -> Slot {
        slot(for: key.stringValue)
    }

    /// A new slot under the name.
    private func slot(for name: String) -> Slot {
        let slot: Slot = Slot()
        encoder.slot.keyed?[name] = slot
        return slot
    }
}

private struct SingleContainer: SingleValueEncodingContainer {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    mutating func encode(_ value: Bool) throws { try put(value) }
    mutating func encode(_ value: Double) throws { try put(value) }
    mutating func encode(_ value: Float) throws { try put(value) }
    mutating func encode(_ value: Int) throws { try put(value) }
    mutating func encode(_ value: Int16) throws { try put(value) }
    mutating func encode(_ value: Int32) throws { try put(value) }
    mutating func encode(_ value: Int64) throws { try put(value) }
    mutating func encode(_ value: Int8) throws { try put(value) }
    mutating func encode(_ value: String) throws { try put(value) }
    mutating func encode(_ value: UInt) throws { try put(value) }
    mutating func encode(_ value: UInt16) throws { try put(value) }
    mutating func encode(_ value: UInt32) throws { try put(value) }
    mutating func encode(_ value: UInt64) throws { try put(value) }
    mutating func encode(_ value: UInt8) throws { try put(value) }
    mutating func encode<T: Encodable>(_ value: T) throws { try put(value) }

    mutating func encodeNil() throws {
        encoder.slot.value = .null
    }

    /// Writes the value into the encoder's own slot.
    private func put<T: Encodable>(_ value: T) throws {
        try NodeEncoder.encode(value, into: encoder.slot, at: codingPath)
    }
}

private struct UnkeyedContainer: UnkeyedEncodingContainer {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    var count: Int { encoder.slot.list?.count ?? 0 }

    mutating func encode(_ value: Bool) throws { try put(value) }
    mutating func encode(_ value: Double) throws { try put(value) }
    mutating func encode(_ value: Float) throws { try put(value) }
    mutating func encode(_ value: Int) throws { try put(value) }
    mutating func encode(_ value: Int16) throws { try put(value) }
    mutating func encode(_ value: Int32) throws { try put(value) }
    mutating func encode(_ value: Int64) throws { try put(value) }
    mutating func encode(_ value: Int8) throws { try put(value) }
    mutating func encode(_ value: String) throws { try put(value) }
    mutating func encode(_ value: UInt) throws { try put(value) }
    mutating func encode(_ value: UInt16) throws { try put(value) }
    mutating func encode(_ value: UInt32) throws { try put(value) }
    mutating func encode(_ value: UInt64) throws { try put(value) }
    mutating func encode(_ value: UInt8) throws { try put(value) }
    mutating func encode<T: Encodable>(_ value: T) throws { try put(value) }

    mutating func encodeNil() throws {
        next().slot.value = .null
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let (path, slot): ([any CodingKey], Slot) = next()
        return NodeEncoder(children: nil, codingPath: path, slot: slot).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let (path, slot): ([any CodingKey], Slot) = next()
        return NodeEncoder(children: nil, codingPath: path, slot: slot).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        let (path, slot): ([any CodingKey], Slot) = next()
        return NodeEncoder(children: nil, codingPath: path, slot: slot)
    }

    /// A new slot at the end of the list, with its coding path.
    private func next() -> (path: [any CodingKey], slot: Slot) {
        let path: [any CodingKey] = codingPath + [CodingNode.Key(intValue: count)]
        let slot: Slot = Slot()
        encoder.slot.list?.append(slot)
        return (path, slot)
    }

    /// Writes the value at the end of the list.
    private func put<T: Encodable>(_ value: T) throws {
        let (path, slot): ([any CodingKey], Slot) = next()
        try NodeEncoder.encode(value, into: slot, at: path)
    }
}

private extension CKRecord {

    /// Makes the record's fields match, leaving any that already hold the value untouched so a save uploads only real changes.
    func apply(_ fields: [String: CodingNode]) throws {
        for key in allKeys() where fields[key] == nil { self[key] = nil }
        for (key, node) in fields {
            guard let first: Character = key.first, first.isASCII, first.isLetter, key.count <= 255, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else { throw EncodingError.invalidValue(key, EncodingError.Context(codingPath: [CodingNode.Key(stringValue: key)], debugDescription: "CloudKit field names start with a letter and hold only ASCII letters, digits and underscores, unlike \"\(key)\".")) }
            let value: (any CKRecordValueProtocol)? = try node.field()
            if let old: CodingNode = self[key].flatMap({ CodingNode(field: $0) }), let new: CodingNode = value.flatMap({ CodingNode(field: $0) }), old.isSame(as: new) { continue }
            self[key] = value
        }
    }
}
#endif
