import Foundation

public extension UUID {

    /// A new version 7 UUID for the current time, so values sort by creation time.
    static var timeStamp: UUID {
        UUID(milliseconds: UInt64(max(0, (Date().timeIntervalSince1970 * 1000).rounded())))
    }

    /// Creates a version 7 UUID for the date, or `nil` when the date is before 1970 or past the 48-bit timestamp limit.
    init?(timestamp date: Date) {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        guard (0..<281_474_976_710_656).contains(milliseconds) else { return nil }
        self.init(milliseconds: UInt64(milliseconds))
    }
}

private extension UUID {

    /// Builds an RFC 9562 version 7 UUID from a 48-bit Unix timestamp in milliseconds and random bits.
    init(milliseconds: UInt64) {
        var bytes = UUID().uuid
        bytes.0 = UInt8(truncatingIfNeeded: milliseconds >> 40)
        bytes.1 = UInt8(truncatingIfNeeded: milliseconds >> 32)
        bytes.2 = UInt8(truncatingIfNeeded: milliseconds >> 24)
        bytes.3 = UInt8(truncatingIfNeeded: milliseconds >> 16)
        bytes.4 = UInt8(truncatingIfNeeded: milliseconds >> 8)
        bytes.5 = UInt8(truncatingIfNeeded: milliseconds)
        bytes.6 = (bytes.6 & 0x0F) | 0x70
        bytes.8 = (bytes.8 & 0x3F) | 0x80
        self.init(uuid: bytes)
    }
}
