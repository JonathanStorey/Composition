// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/UUID.swift
// dependencies: [Protocols/Digestible.swift]

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

public extension UUID {

    /// Creates a version 7 UUID for the date, or `nil` when the date is before 1970 or past the 48-bit timestamp limit.
    init?(timestamp date: Date) {
        let unixTime: TimeInterval = date.timeIntervalSince1970
        guard (0..<281_474_976_710.656).contains(unixTime) else { return nil }
        self.init(unixTime: unixTime)
    }

    /// The max UUID, with all 128 bits set to one.
    static let max = UUID(uuid: (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))

    /// A new version 7 UUID for the current time, with sub-millisecond precision so values sort by creation time.
    static var timestamp: UUID {
        UUID(unixTime: Swift.max(0, Date().timeIntervalSince1970))
    }

    /// The nil UUID, with all 128 bits set to zero.
    static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// The RFC 9562 version number, or `nil` when the UUID does not use the RFC 9562 variant.
    var version: Int? {
        guard uuid.8 & 0xC0 == 0x80 else { return nil }
        return Int(uuid.6 >> 4)
    }
}

private extension UUID {

    /// Builds an RFC 9562 version 7 UUID with 12 bits of sub-millisecond precision (Method 3) and 62 random bits.
    init(unixTime: TimeInterval) {
        let seconds: TimeInterval = unixTime.rounded(.down)
        let subsecondMilliseconds: Double = (unixTime - seconds) * 1000
        let millisecondOfSecond: Double = subsecondMilliseconds.rounded(.down)
        let milliseconds: UInt64 = UInt64(seconds) * 1000 + UInt64(millisecondOfSecond)
        let fraction: UInt16 = UInt16(min(4095, (subsecondMilliseconds - millisecondOfSecond) * 4096))

        var bytes: uuid_t = UUID().uuid
        bytes.0 = UInt8(truncatingIfNeeded: milliseconds >> 40)
        bytes.1 = UInt8(truncatingIfNeeded: milliseconds >> 32)
        bytes.2 = UInt8(truncatingIfNeeded: milliseconds >> 24)
        bytes.3 = UInt8(truncatingIfNeeded: milliseconds >> 16)
        bytes.4 = UInt8(truncatingIfNeeded: milliseconds >> 8)
        bytes.5 = UInt8(truncatingIfNeeded: milliseconds)
        bytes.6 = 0x70 | UInt8(fraction >> 8)
        bytes.7 = UInt8(truncatingIfNeeded: fraction)
        bytes.8 = (bytes.8 & 0x3F) | 0x80
        self.init(uuid: bytes)
    }
}
#endif

// MARK: - CryptoKit + Foundation

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension UUID {

    /// Creates the value's checksum in the namespace of the given name, or of the value's type name when there is none.
    init<D: Digestible>(digest value: D, namespace name: String? = nil) {
        var digester: Digester = Digester(namespace: name ?? String(describing: D.self))
        value.digest(into: &digester)
        self = digester.finalize()
    }
}
#endif
