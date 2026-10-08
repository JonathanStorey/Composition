// MARK: - Foundation

#if canImport(Foundation)
import Foundation

public extension UUID {

    /// Creates a version 7 UUID for the date, or `nil` when the date is before 1970 or past the 48-bit timestamp limit.
    init?(timestamp date: Date) {
        let unixTime = date.timeIntervalSince1970
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
        let seconds = unixTime.rounded(.down)
        let subsecondMilliseconds = (unixTime - seconds) * 1000
        let millisecondOfSecond = subsecondMilliseconds.rounded(.down)
        let milliseconds = UInt64(seconds) * 1000 + UInt64(millisecondOfSecond)
        let fraction = UInt16(min(4095, (subsecondMilliseconds - millisecondOfSecond) * 4096))

        var bytes = UUID().uuid
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
import CryptoKit
import Foundation

public extension UUID {

    /// Creates a version 5 UUID from the value's contents within a namespace that is itself the version 5 UUID of the name.
    init(hash value: some Encodable, namespace name: String) throws {
        try self.init(hash: value, namespace: UUID(name: Data(name.utf8), namespace: .zero))
    }

    /// Creates a version 5 UUID from the value's contents, so equal values with the same namespace always give the same UUID.
    init(hash value: some Encodable, namespace uuid: UUID = .zero) throws {
        if let data = value as? Data {
            self.init(name: data, namespace: uuid)
        } else if let string = value as? String {
            self.init(name: Data(string.utf8), namespace: uuid)
        } else {
            self.init(name: try JSONEncoder().encode(value, compatibility: .python), namespace: uuid)
        }
    }
}

extension UUID {

    /// Builds an RFC 9562 version 5 UUID from the SHA-1 digest of a namespace followed by a name.
    init(name: Data, namespace: UUID) {
        var data = withUnsafeBytes(of: namespace.uuid) { Data($0) }
        data.append(name)
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self.init(uuid: bytes.withUnsafeBytes { $0.load(as: uuid_t.self) })
    }
}
#endif
