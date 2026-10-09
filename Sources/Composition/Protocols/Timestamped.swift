// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Timestamped.swift
// dependencies: [Extensions/Date.swift]

#if canImport(Foundation)
import Foundation

/// A type that records when it was made with a version 7 UUID.
public protocol Timestamped {

    /// A version 7 UUID whose embedded time orders values and breaks ties between them.
    var timestamp: UUID { get }
}

public extension Timestamped {

    /// The time embedded in the timestamp, or `nil` when the timestamp is not a version 7 UUID.
    var date: Date? {
        Date(timestamp: timestamp)
    }
}
#endif
