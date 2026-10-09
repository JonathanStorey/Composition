// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Shiftable.swift
// dependencies: []

/// A change that can be moved past a concurrent change, keeping only its own effect.
public protocol Shiftable {

    /// Returns only this change, moved to apply after a prior change made from the same starting point.
    func shifted(by prior: Self) throws -> Self
}

public extension Shiftable {

    /// Moves this change to apply after a prior change made from the same starting point.
    mutating func shift(by prior: Self) throws {
        self = try shifted(by: prior)
    }
}
