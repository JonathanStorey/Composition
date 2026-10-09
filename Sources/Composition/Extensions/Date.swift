// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/Date.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

public extension Date {

    /// Creates the date embedded in a version 7 UUID, or `nil` when the UUID is not version 7.
    init?(timestamp uuid: UUID) {
        let bytes = uuid.uuid
        guard bytes.6 >> 4 == 7, bytes.8 >> 6 == 0b10 else { return nil }
        let milliseconds = [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let fraction = UInt16(bytes.6 & 0x0F) << 8 | UInt16(bytes.7)
        self.init(timeIntervalSince1970: (TimeInterval(milliseconds) + TimeInterval(fraction) / 4096) / 1000)
    }

    /// The date described relative to now, such as "now", "2 minutes ago", "yesterday", or "in 3 days".
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    var relativeDescription: String {
        formatted(.relative(presentation: .named))
    }
}

extension Date {

    /// The whole microseconds since 1970, the precision Python's `datetime` holds.
    var microsecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1_000_000).rounded())
    }
}
#endif
