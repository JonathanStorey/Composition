import Foundation

public extension UUID {

    /// A new version 7 UUID for the current time, with sub-millisecond precision so values sort by creation time.
    static var timeStamp: UUID {
        UUID(unixTime: max(0, Date().timeIntervalSince1970))
    }

    /// Creates a version 7 UUID for the date, or `nil` when the date is before 1970 or past the 48-bit timestamp limit.
    init?(timestamp date: Date) {
        let unixTime = date.timeIntervalSince1970
        guard (0..<281_474_976_710.656).contains(unixTime) else { return nil }
        self.init(unixTime: unixTime)
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
