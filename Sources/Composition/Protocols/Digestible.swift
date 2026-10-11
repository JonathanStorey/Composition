// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Digestible.swift
// dependencies: [Extensions/Date.swift, Extensions/Decimal.swift, Extensions/UUID.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import CryptoKit
import Foundation

/// A type that feeds a stable, platform-independent representation of its content into a digester.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Digestible {

    /// Feeds the value's content into the digester.
    func digest(into digester: inout Digester)
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Digestible {

    /// Returns the version 5 UUID of the content's digest in the namespace of the type's name, identical on every device and every launch.
    func checksum() -> UUID {
        UUID(digest: self)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Digestible where Self: Encodable {

    /// Feeds the encoded properties as a dictionary of names to values, using each digestible property's own digest and leaving out nil properties.
    func digest(into digester: inout Digester) {
        let node: Digester.Encoder.Node = Digester.Encoder.Node()
        // Only a custom encode(to:) that throws on purpose, or an integer beyond Int64, can trap here.
        try! encode(to: Digester.Encoder(codingPath: [], node: node))
        node.digest(into: &digester)
    }
}

/// Accumulates digestible values into a checksum, as `Hasher` accumulates hashable values into a hash value.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Digester {

    /// The name whose version 5 UUID is the checksum's namespace.
    public let namespace: String

    private var hasher: SHA256 = SHA256()

    /// Creates an empty digester whose checksum falls in the namespace of the name.
    public init(namespace: String) {
        self.namespace = namespace
    }

    /// Returns the 32-byte SHA-256 digest of the value's content, which a parent feeds in place of the content itself.
    fileprivate static func digest(of value: some Digestible) -> Data {
        var digester: Digester = Digester(namespace: "")
        value.digest(into: &digester)
        return Data(digester.hasher.finalize())
    }

    /// Feeds the value's 32-byte digest, so adjacent values cannot run together.
    public mutating func combine<D: Digestible>(_ value: D) {
        hasher.update(data: Self.digest(of: value))
    }

    /// Feeds raw bytes unchanged, for a leaf value's own encoding.
    public mutating func combine(bytes: Data) {
        hasher.update(data: bytes)
    }

    /// Returns the version 5 UUID of the SHA-256 digest of everything fed in so far, within the namespace named by `namespace`.
    public func finalize() -> UUID {
        UUID(name: Data(hasher.finalize()), namespace: UUID(name: Data(namespace.utf8), namespace: .zero))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
fileprivate extension Digester {

    /// Encodes a value into a tree of nodes whose digests follow the standard conformances: keyed containers as dictionaries and unkeyed containers as arrays.
    struct Encoder: Swift.Encoder {

        let codingPath: [any CodingKey]
        let node: Node

        /// Returns the node for a value, `nil` for a nil optional, a leaf for a digestible value, and the encoded contents for everything else.
        static func node(for value: some Encodable, codingPath: [any CodingKey]) throws -> Node? {
            switch value {
            case let optional as any OptionalValue where optional.isNone: return nil
            case let digestible as any Digestible: return Node(leaf: digestible)
            case let float as Float: return Node(leaf: Double(float))
            case let integer as any BinaryInteger:
                guard let int: Int = Int(exactly: integer) else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "\(integer) does not fit in the 64-bit integer a digest feeds.")) }
                return Node(leaf: int)
            default:
                let node: Node = Node()
                try value.encode(to: Encoder(codingPath: codingPath, node: node))
                return node
            }
        }

        var userInfo: [CodingUserInfoKey: Any] { [:] }

        func container<K: CodingKey>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> {
            if node.members == nil { node.members = [:] }
            return KeyedEncodingContainer(KeyedContainer<K>(codingPath: codingPath, node: node))
        }

        func singleValueContainer() -> any SingleValueEncodingContainer {
            SingleValueContainer(codingPath: codingPath, node: node)
        }

        func unkeyedContainer() -> any UnkeyedEncodingContainer {
            if node.elements == nil { node.elements = [] }
            return UnkeyedContainer(codingPath: codingPath, node: node)
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
fileprivate extension Digester.Encoder {

    /// Writes keyed values into a node's members, removing a key whose value is nil.
    struct KeyedContainer<K: CodingKey>: KeyedEncodingContainerProtocol {

        let codingPath: [any CodingKey]
        let node: Node

        mutating func encode(_ value: Bool, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Double, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Float, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Int, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Int8, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Int16, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Int32, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: Int64, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: String, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: UInt, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: UInt8, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: UInt16, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: UInt32, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode(_ value: UInt64, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws { try set(value, forKey: key) }

        mutating func encodeNil(forKey key: K) throws {
            node.members?[key.stringValue] = nil
        }

        mutating func nestedContainer<N: CodingKey>(keyedBy keyType: N.Type, forKey key: K) -> KeyedEncodingContainer<N> {
            Digester.Encoder(codingPath: codingPath + [key], node: child(named: key.stringValue)).container(keyedBy: keyType)
        }

        mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
            Digester.Encoder(codingPath: codingPath + [key], node: child(named: key.stringValue)).unkeyedContainer()
        }

        mutating func superEncoder() -> any Swift.Encoder {
            Digester.Encoder(codingPath: codingPath, node: child(named: "super"))
        }

        mutating func superEncoder(forKey key: K) -> any Swift.Encoder {
            Digester.Encoder(codingPath: codingPath + [key], node: child(named: key.stringValue))
        }

        private func child(named name: String) -> Node {
            let child: Node = Node()
            node.members?[name] = child
            return child
        }

        private func set(_ value: some Encodable, forKey key: K) throws {
            node.members?[key.stringValue] = try Digester.Encoder.node(for: value, codingPath: codingPath + [key])
        }
    }

    /// A value under construction: a digestible leaf, the members of a keyed container, or the elements of an unkeyed one.
    final class Node: Digestible {

        var elements: [Node]?
        var leaf: (any Digestible)?
        var members: [String: Node]?

        init(leaf: (any Digestible)? = nil) {
            self.leaf = leaf
        }

        /// A nil value, which digests like `Optional.none`.
        static var null: Node {
            Node(leaf: Bool?.none)
        }

        /// Copies another node's contents into this one.
        func assign(_ node: Node) {
            elements = node.elements
            leaf = node.leaf
            members = node.members
        }

        /// Feeds the leaf unchanged, the elements as an array, or the members as a dictionary.
        func digest(into digester: inout Digester) {
            if let leaf { return leaf.digest(into: &digester) }
            if let elements { return elements.digest(into: &digester) }
            members?.digest(into: &digester)
        }
    }

    /// Writes a single value into a node.
    struct SingleValueContainer: SingleValueEncodingContainer {

        let codingPath: [any CodingKey]
        let node: Node

        mutating func encode(_ value: Bool) throws { try set(value) }

        mutating func encode(_ value: Double) throws { try set(value) }

        mutating func encode(_ value: Float) throws { try set(value) }

        mutating func encode(_ value: Int) throws { try set(value) }

        mutating func encode(_ value: Int8) throws { try set(value) }

        mutating func encode(_ value: Int16) throws { try set(value) }

        mutating func encode(_ value: Int32) throws { try set(value) }

        mutating func encode(_ value: Int64) throws { try set(value) }

        mutating func encode(_ value: String) throws { try set(value) }

        mutating func encode(_ value: UInt) throws { try set(value) }

        mutating func encode(_ value: UInt8) throws { try set(value) }

        mutating func encode(_ value: UInt16) throws { try set(value) }

        mutating func encode(_ value: UInt32) throws { try set(value) }

        mutating func encode(_ value: UInt64) throws { try set(value) }

        mutating func encode<T: Encodable>(_ value: T) throws { try set(value) }

        mutating func encodeNil() throws {
            node.assign(.null)
        }

        private func set(_ value: some Encodable) throws {
            node.assign(try Digester.Encoder.node(for: value, codingPath: codingPath) ?? .null)
        }
    }

    /// Appends values to a node's elements, with a nil value digested like `Optional.none`.
    struct UnkeyedContainer: UnkeyedEncodingContainer {

        let codingPath: [any CodingKey]
        let node: Node

        var count: Int { node.elements?.count ?? 0 }

        mutating func encode(_ value: Bool) throws { try set(value) }

        mutating func encode(_ value: Double) throws { try set(value) }

        mutating func encode(_ value: Float) throws { try set(value) }

        mutating func encode(_ value: Int) throws { try set(value) }

        mutating func encode(_ value: Int8) throws { try set(value) }

        mutating func encode(_ value: Int16) throws { try set(value) }

        mutating func encode(_ value: Int32) throws { try set(value) }

        mutating func encode(_ value: Int64) throws { try set(value) }

        mutating func encode(_ value: String) throws { try set(value) }

        mutating func encode(_ value: UInt) throws { try set(value) }

        mutating func encode(_ value: UInt8) throws { try set(value) }

        mutating func encode(_ value: UInt16) throws { try set(value) }

        mutating func encode(_ value: UInt32) throws { try set(value) }

        mutating func encode(_ value: UInt64) throws { try set(value) }

        mutating func encode<T: Encodable>(_ value: T) throws { try set(value) }

        mutating func encodeNil() throws {
            _ = append(.null)
        }

        mutating func nestedContainer<N: CodingKey>(keyedBy keyType: N.Type) -> KeyedEncodingContainer<N> {
            Digester.Encoder(codingPath: codingPath, node: append(Node())).container(keyedBy: keyType)
        }

        mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            Digester.Encoder(codingPath: codingPath, node: append(Node())).unkeyedContainer()
        }

        mutating func superEncoder() -> any Swift.Encoder {
            Digester.Encoder(codingPath: codingPath, node: append(Node()))
        }

        private func append(_ child: Node) -> Node {
            node.elements?.append(child)
            return child
        }

        private func set(_ value: some Encodable) throws {
            _ = append(try Digester.Encoder.node(for: value, codingPath: codingPath) ?? .null)
        }
    }
}

/// A type that can say whether it holds a nil optional, so the encoder can leave nil properties out.
private protocol OptionalValue {

    /// A Boolean value indicating whether the value is nil.
    var isNone: Bool { get }
}

extension Optional: OptionalValue {

    /// A Boolean value indicating whether the value is nil.
    fileprivate var isNone: Bool { self == nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Array: Digestible where Element: Digestible {

    /// Feeds the digest of each element in order.
    public func digest(into digester: inout Digester) {
        forEach { digester.combine($0) }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Bool: Digestible {

    /// Feeds the value as a single byte.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: Data([self ? 1 : 0]))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Data: Digestible {

    /// Feeds the bytes unchanged.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: self)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Date: Digestible {

    /// Feeds the whole microseconds since 1970 as eight big-endian bytes, matching Python's `datetime` precision.
    public func digest(into digester: inout Digester) {
        Int(microsecondsSince1970).digest(into: &digester)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Decimal: Digestible {

    /// Feeds the UTF-8 bytes of the plain normalized string, such as "1.5" for 1.50.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: Data(normalizedDescription.utf8))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Dictionary: Digestible where Key: Digestible, Value: Digestible {

    /// Feeds each key's digest followed by its value's digest, with the pairs sorted so insertion order does not matter.
    public func digest(into digester: inout Digester) {
        map { Digester.digest(of: $0.key) + Digester.digest(of: $0.value) }.sorted { $0.lexicographicallyPrecedes($1) }.forEach { digester.combine(bytes: $0) }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Double: Digestible {

    /// Feeds the exact bit pattern in big-endian order.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: withUnsafeBytes(of: bitPattern.bigEndian) { Data($0) })
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Int: Digestible {

    /// Feeds the value as eight big-endian bytes on every platform.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: withUnsafeBytes(of: Int64(self).bigEndian) { Data($0) })
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Optional: Digestible where Wrapped: Digestible {

    /// Feeds the wrapped value unchanged, or 32 zero bytes when there is none.
    public func digest(into digester: inout Digester) {
        guard let value = self else { return digester.combine(bytes: Data(count: 32)) }
        value.digest(into: &digester)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Set: Digestible where Element: Digestible {

    /// Feeds each element's digest, sorted so iteration order does not matter.
    public func digest(into digester: inout Digester) {
        map { Digester.digest(of: $0) }.sorted { $0.lexicographicallyPrecedes($1) }.forEach { digester.combine(bytes: $0) }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension String: Digestible {

    /// Feeds the UTF-8 bytes unchanged, matching how Python encodes the string.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: Data(utf8))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension UUID: Digestible {

    /// Feeds the sixteen raw bytes.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: withUnsafeBytes(of: uuid) { Data($0) })
    }
}
#endif
