#if canImport(Foundation)
import Foundation

public extension JSONEncoder {

    /// A JSON dialect that another language's standard library writes byte for byte.
    enum Compatibility: Sendable {

        /// RFC 8785's JSON Canonicalization Scheme, with dates as whole microseconds since 1970, data as base64, and decimals as numbers.
        case jcs

        /// Python's `json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`, with dates as whole microseconds since 1970, data as base64, and decimals as plain numbers.
        case python
    }

    /// Returns the value's JSON written exactly as the compatibility target writes it, ignoring this encoder's own settings.
    func encode(_ value: some Encodable, compatibility: Compatibility) throws -> Data {
        let format = JSONFormat(compatibility: compatibility)
        return Data(format.text(of: try format.node(for: value, codingPath: [])).utf8)
    }
}

/// Builds and renders JSON in a compatibility target's format.
private struct JSONFormat {

    let compatibility: JSONEncoder.Compatibility

    /// Returns the string quoted and escaped as Python's `json.dumps` with `ensure_ascii=False` and RFC 8785 both escape it.
    static func quoted(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{8}": result += "\\b"
            case "\u{C}": result += "\\f"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    /// Returns the node for a value, writing dates, data, decimals, URLs and scalars directly and everything else through its `Encodable` conformance.
    func node(for value: some Encodable, codingPath: [any CodingKey]) throws -> Node {
        switch value {
        case let bool as Bool: return Node(text: bool ? "true" : "false")
        case let data as Data: return Node(text: Self.quoted(data.base64EncodedString()))
        case let date as Date: return Node(text: String(date.microsecondsSince1970))
        case let decimal as Decimal: return Node(text: try compatibility == .python ? decimal.normalizedDescription : number(Double(decimal.normalizedDescription) ?? .nan, codingPath: codingPath))
        case let double as Double: return Node(text: try number(double, codingPath: codingPath))
        case let float as Float: return Node(text: try number(Double(float), codingPath: codingPath))
        case let integer as any BinaryInteger: return Node(text: try compatibility == .python ? String(describing: integer) : number(Double(integer), codingPath: codingPath))
        case let string as String: return Node(text: Self.quoted(string))
        case let url as URL: return Node(text: Self.quoted(url.absoluteString))
        default:
            let node = Node()
            try value.encode(to: Writer(codingPath: codingPath, format: self, node: node))
            return node
        }
    }

    /// Returns the number formatted as Python's `repr` or ECMAScript's `Number.prototype.toString` formats it.
    func number(_ value: Double, codingPath: [any CodingKey]) throws -> String {
        guard value.isFinite else {
            guard compatibility == .python else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "RFC 8785 has no representation for \(value).")) }
            if value.isNaN { return "NaN" }
            return value < 0 ? "-Infinity" : "Infinity"
        }
        let parts = "\(value.magnitude)".split(separator: "e")
        let mantissa = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        var digits = mantissa.joined()
        var point = mantissa[0].count + (parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        while digits.hasPrefix("0") {
            digits.removeFirst()
            point -= 1
        }
        while digits.hasSuffix("0") { digits.removeLast() }
        let exponent = point - 1
        let significand = digits.count > 1 ? String(digits.prefix(1)) + "." + String(digits.dropFirst()) : digits
        let exponentSign = exponent < 0 ? "-" : "+"
        switch compatibility {
        case .jcs:
            guard !digits.isEmpty else { return "0" }
            let sign = value < 0 ? "-" : ""
            if digits.count <= point && point <= 21 { return sign + digits + String(repeating: "0", count: point - digits.count) }
            if point > 0 && point <= 21 { return sign + String(digits.prefix(point)) + "." + String(digits.dropFirst(point)) }
            if point > -6 && point <= 0 { return sign + "0." + String(repeating: "0", count: -point) + digits }
            return sign + significand + "e" + exponentSign + String(abs(exponent))
        case .python:
            let sign = value.sign == .minus ? "-" : ""
            guard !digits.isEmpty else { return sign + "0.0" }
            if point > -4 && point <= 16 {
                if point <= 0 { return sign + "0." + String(repeating: "0", count: -point) + digits }
                if point >= digits.count { return sign + digits + String(repeating: "0", count: point - digits.count) + ".0" }
                return sign + String(digits.prefix(point)) + "." + String(digits.dropFirst(point))
            }
            let exponentDigits = abs(exponent) < 10 ? "0" + String(abs(exponent)) : String(abs(exponent))
            return sign + significand + "e" + exponentSign + exponentDigits
        }
    }

    /// Returns the node rendered as compact JSON, with object keys sorted as the compatibility target sorts them.
    func text(of node: Node) -> String {
        if let scalar = node.scalar { return scalar }
        if let elements = node.elements { return "[" + elements.map { text(of: $0) }.joined(separator: ",") + "]" }
        let members = node.members ?? [:]
        let keys = switch compatibility {
        case .jcs: members.keys.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
        case .python: members.keys.sorted { $0.unicodeScalars.lexicographicallyPrecedes($1.unicodeScalars) }
        }
        return "{" + keys.map { Self.quoted($0) + ":" + (members[$0].map { text(of: $0) } ?? "null") }.joined(separator: ",") + "}"
    }
}

/// A JSON value under construction, filled in by the containers and rendered once encoding finishes.
private final class Node {

    var elements: [Node]?
    var members: [String: Node]?
    var scalar: String?

    init(text: String? = nil) {
        scalar = text
    }

    /// Copies another node's contents into this one.
    func assign(_ node: Node) {
        elements = node.elements
        members = node.members
        scalar = node.scalar
    }
}

/// The encoder handed to `Encodable` values, writing into a node.
private struct Writer: Encoder {

    let codingPath: [any CodingKey]
    let format: JSONFormat
    let node: Node

    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<K: CodingKey>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> {
        if node.members == nil { node.members = [:] }
        return KeyedEncodingContainer(KeyedWriter<K>(codingPath: codingPath, format: format, node: node))
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleValueWriter(codingPath: codingPath, format: format, node: node)
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        if node.elements == nil { node.elements = [] }
        return UnkeyedWriter(codingPath: codingPath, format: format, node: node)
    }
}

/// Writes keyed values into a node's members.
private struct KeyedWriter<K: CodingKey>: KeyedEncodingContainerProtocol {

    let codingPath: [any CodingKey]
    let format: JSONFormat
    let node: Node

    func child(named name: String) -> Node {
        let child = Node()
        node.members?[name] = child
        return child
    }

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
        node.members?[key.stringValue] = Node(text: "null")
    }

    mutating func nestedContainer<N: CodingKey>(keyedBy keyType: N.Type, forKey key: K) -> KeyedEncodingContainer<N> {
        Writer(codingPath: codingPath + [key], format: format, node: child(named: key.stringValue)).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
        Writer(codingPath: codingPath + [key], format: format, node: child(named: key.stringValue)).unkeyedContainer()
    }

    func set(_ value: some Encodable, forKey key: K) throws {
        node.members?[key.stringValue] = try format.node(for: value, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> any Encoder {
        Writer(codingPath: codingPath, format: format, node: child(named: "super"))
    }

    mutating func superEncoder(forKey key: K) -> any Encoder {
        Writer(codingPath: codingPath + [key], format: format, node: child(named: key.stringValue))
    }
}

/// Writes a single value into a node.
private struct SingleValueWriter: SingleValueEncodingContainer {

    let codingPath: [any CodingKey]
    let format: JSONFormat
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
        node.assign(Node(text: "null"))
    }

    func set(_ value: some Encodable) throws {
        node.assign(try format.node(for: value, codingPath: codingPath))
    }
}

/// Appends values to a node's elements.
private struct UnkeyedWriter: UnkeyedEncodingContainer {

    let codingPath: [any CodingKey]
    let format: JSONFormat
    let node: Node

    var count: Int { node.elements?.count ?? 0 }

    func append(_ child: Node) -> Node {
        node.elements?.append(child)
        return child
    }

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
        _ = append(Node(text: "null"))
    }

    mutating func nestedContainer<N: CodingKey>(keyedBy keyType: N.Type) -> KeyedEncodingContainer<N> {
        Writer(codingPath: codingPath, format: format, node: append(Node())).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        Writer(codingPath: codingPath, format: format, node: append(Node())).unkeyedContainer()
    }

    func set(_ value: some Encodable) throws {
        _ = append(try format.node(for: value, codingPath: codingPath))
    }

    mutating func superEncoder() -> any Encoder {
        Writer(codingPath: codingPath, format: format, node: append(Node()))
    }
}
#endif
