// repository: https://github.com/JonathanStorey/Composition
// path: Coders/CKEncoder.swift
// dependencies: [Coders/CodingNode.swift, Extensions/CKRecord.swift, Extensions/CKRecordZone.swift, Protocols/CKRecordable.swift]

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// Encodes values into the fields of CloudKit records, the way `JSONEncoder` encodes them into JSON.
public struct CKEncoder: Sendable {

    /// Creates an encoder.
    public init() {}

    /// Encodes the value into a new record named `Type.id` in the zone.
    public func encode<R: CKRecordable>(_ value: R, in zoneID: CKRecordZone.ID = .defaultZone) throws -> CKRecord {
        let recordType: CKRecord.RecordType = CKRecord.recordType(of: R.self)
        let name: String = "\(recordType).\(value.id)"
        guard name.count <= 255, name.allSatisfy(\.isASCII) else { throw EncodingError.invalidValue(value.id, EncodingError.Context(codingPath: [], debugDescription: "CloudKit needs a record name of at most 255 ASCII characters, unlike \"\(name)\".")) }
        let record: CKRecord = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
        try encode(value, to: record)
        return record
    }

    /// Encodes the value into the record's fields, clearing the ones it names as nil or empty and leaving unchanged fields, and fields it doesn't name, untouched.
    public func encode<T: Encodable>(_ value: T, to record: CKRecord) throws {
        let slot: Slot = Slot()
        try NodeEncoder.encode(value, into: slot, at: [])
        guard case .keyed(let fields) = slot.node else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "A record keeps a keyed value, unlike \(T.self).")) }
        try record.apply(fields)
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

    let codingPath: [any CodingKey]
    let slot: Slot
    let userInfo: [CodingUserInfoKey: Any] = [:]

    /// Writes the value into the slot, natively when CloudKit keeps its type and otherwise as whatever its own `encode(to:)` writes.
    static func encode<T: Encodable>(_ value: T, into slot: Slot, at path: [any CodingKey]) throws {
        if let node: CodingNode = try CodingNode(native: value, at: path) { slot.value = node } else { try value.encode(to: NodeEncoder(codingPath: path, slot: slot)) }
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

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try putIfPresent(value, key) }
    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws { try putIfPresent(value, key) }

    mutating func encodeNil(forKey key: Key) throws {
        slot(for: key).value = .null
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        NodeEncoder(codingPath: codingPath + [key], slot: slot(for: key)).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        NodeEncoder(codingPath: codingPath + [key], slot: slot(for: key)).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        NodeEncoder(codingPath: codingPath + [CodingNode.Key.superKey], slot: slot(for: CodingNode.Key.superKey.stringValue))
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        NodeEncoder(codingPath: codingPath + [key], slot: slot(for: key))
    }

    /// Writes the value under the key.
    private func put<T: Encodable>(_ value: T, _ key: Key) throws {
        try NodeEncoder.encode(value, into: slot(for: key), at: codingPath + [key])
    }

    /// Writes the value under the key, or for nil at a record's root clears the field, while nested nils are left out as in JSON.
    private func putIfPresent<T: Encodable>(_ value: T?, _ key: Key) throws {
        if let value { try put(value, key) } else if codingPath.isEmpty { slot(for: key).value = .null }
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
        return NodeEncoder(codingPath: path, slot: slot).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let (path, slot): ([any CodingKey], Slot) = next()
        return NodeEncoder(codingPath: path, slot: slot).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        let (path, slot): ([any CodingKey], Slot) = next()
        return NodeEncoder(codingPath: path, slot: slot)
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

    /// Writes the fields, skipping any that already hold the value so a save uploads only real changes, and leaving fields the value doesn't name alone.
    func apply(_ fields: [String: CodingNode]) throws {
        for (key, node) in fields {
            guard let first: Character = key.first, first.isASCII, first.isLetter, key.count <= 255, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else { throw EncodingError.invalidValue(key, EncodingError.Context(codingPath: [CodingNode.Key(stringValue: key)], debugDescription: "CloudKit field names start with a letter and hold only ASCII letters, digits and underscores, unlike \"\(key)\".")) }
            let value: (any CKRecordValueProtocol)? = try node.field()
            if value == nil, self[key] == nil { continue }  // already clear
            if let old: CodingNode = self[key].flatMap({ CodingNode(field: $0) }), let new: CodingNode = value.flatMap({ CodingNode(field: $0) }), old.isSame(as: new) { continue }
            self[key] = value
        }
    }
}
#endif
