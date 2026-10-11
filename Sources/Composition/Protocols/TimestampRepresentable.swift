// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/TimestampRepresentable.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift]

#if canImport(Foundation)
import Foundation

/// A type that can be read from a version 7 UUID, such as the UUID itself or the date embedded in it.
public protocol TimestampRepresentable {

    /// Creates a value from the version 7 UUID, or `nil` when the UUID is not version 7.
    init?(timestamp uuid: UUID)
}

extension Date: TimestampRepresentable {}

extension UUID: TimestampRepresentable {

    /// Returns the UUID when it is version 7, or `nil` otherwise.
    public init?(timestamp uuid: UUID) {
        guard uuid.version == 7 else { return nil }
        self = uuid
    }
}
#endif
