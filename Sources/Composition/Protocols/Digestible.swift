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

    /// Feeds a digestible value into the digester.
    public mutating func combine<D: Digestible>(_ value: D) {
        value.digest(into: &self)
    }

    /// Feeds raw bytes into the digester, prefixed with their length so adjacent values cannot run together.
    public mutating func combine(bytes: Data) {
        hasher.update(data: withUnsafeBytes(of: UInt64(bytes.count).bigEndian) { Data($0) })
        hasher.update(data: bytes)
    }

    /// Returns the checksum of everything fed in so far.
    public func finalize() -> Checksum {
        Checksum(bytes: Data(hasher.finalize()))
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Array: Digestible where Element: Digestible {

    /// Feeds the count followed by each element in order.
    public func digest(into digester: inout Digester) {
        digester.combine(count)
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

    /// Feeds the exact time interval since 1970.
    public func digest(into digester: inout Digester) {
        digester.combine(timeIntervalSince1970)
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

    /// Feeds a presence flag followed by the wrapped value when there is one.
    public func digest(into digester: inout Digester) {
        digester.combine(self != nil)
        if let value = self { digester.combine(value) }
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
