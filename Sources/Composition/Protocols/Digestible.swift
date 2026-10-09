// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Digestible.swift
// dependencies: [Extensions/Date.swift, Extensions/Decimal.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import CryptoKit
import Foundation

/// A type that feeds a stable, platform-independent representation of its content into a digester.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Digestible {

    /// The SHA-256 checksum of the value's content, identical on every device and every launch.
    var checksum: Checksum { get }

    /// Feeds the value's content into the digester.
    func digest(into digester: inout Digester)
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Digestible {

    /// The SHA-256 checksum of the value's content, identical on every device and every launch.
    var checksum: Checksum {
        var digester = Digester()
        digest(into: &digester)
        return digester.finalize()
    }
}

/// A SHA-256 checksum, compared, hashed and stored by value.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Checksum: Codable, Hashable, Sendable {

    /// The 32 raw bytes of the checksum.
    public let bytes: Data
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Checksum: CustomStringConvertible {

    /// The checksum as lowercase hexadecimal.
    public var description: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// Accumulates digestible values into a SHA-256 checksum.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Digester {

    private var hasher = SHA256()

    /// Creates an empty digester.
    public init() {}

    /// Feeds the value's 32-byte checksum, so adjacent values cannot run together.
    public mutating func combine<D: Digestible>(_ value: D) {
        hasher.update(data: value.checksum.bytes)
    }

    /// Feeds raw bytes unchanged, for a leaf value's own encoding.
    public mutating func combine(bytes: Data) {
        hasher.update(data: bytes)
    }

    /// Returns the checksum of everything fed in so far.
    public func finalize() -> Checksum {
        Checksum(bytes: Data(hasher.finalize()))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Array: Digestible where Element: Digestible {

    /// Feeds the checksum of each element in order.
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
extension Checksum: Digestible {

    /// The checksum itself, so a checksum is never hashed again.
    public var checksum: Checksum { self }

    /// Feeds the raw bytes.
    public func digest(into digester: inout Digester) {
        digester.combine(bytes: bytes)
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

    /// Feeds each key's checksum followed by its value's checksum, with the pairs sorted so insertion order does not matter.
    public func digest(into digester: inout Digester) {
        map { $0.key.checksum.bytes + $0.value.checksum.bytes }.sorted { $0.lexicographicallyPrecedes($1) }.forEach { digester.combine(bytes: $0) }
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

    /// The wrapped value's checksum, or 32 zero bytes when there is none.
    public var checksum: Checksum {
        self?.checksum ?? Checksum(bytes: Data(count: 32))
    }

    /// Feeds the wrapped value unchanged, or 32 zero bytes when there is none.
    public func digest(into digester: inout Digester) {
        guard let value = self else { return digester.combine(bytes: Data(count: 32)) }
        value.digest(into: &digester)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Set: Digestible where Element: Digestible {

    /// Feeds each element's checksum, sorted so iteration order does not matter.
    public func digest(into digester: inout Digester) {
        map(\.checksum.bytes).sorted { $0.lexicographicallyPrecedes($1) }.forEach { digester.combine(bytes: $0) }
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
