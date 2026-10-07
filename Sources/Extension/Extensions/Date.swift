import Foundation

public extension Date {

    /// The date described relative to now, such as "now", "2 minutes ago", "yesterday", or "in 3 days".
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    var relativeDescription: String {
        formatted(.relative(presentation: .named))
    }

    /// Creates the date embedded in a version 7 UUID, or `nil` when the UUID is not version 7.
    init?(timestamp uuid: UUID) {
        let bytes = uuid.uuid
        guard bytes.6 >> 4 == 7, bytes.8 >> 6 == 0b10 else { return nil }
        let milliseconds = [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5]
            .reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
