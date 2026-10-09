// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Mergeable.swift
// dependencies: [Protocols/Squashable.swift]

/// A change that can be combined with another change made concurrently from the same starting point.
public protocol Mergeable: Squashable {

    /// Returns only this change, moved to apply after a prior change made from the same starting point.
    func adjusted(for prior: Self) throws -> Self
}

public extension Mergeable {

    /// Returns one change making the first change and the other, where both were made from the same starting point.
    static func merged(_ first: Self, with other: Self) throws -> Self {
        try first.merged(with: other)
    }

    /// Combines the other change, made from the same starting point, into this one.
    mutating func merge(with other: Self) throws {
        self = try merged(with: other)
    }

    /// Returns one change making this change and the other, where both were made from the same starting point.
    func merged(with other: Self) throws -> Self {
        try squashed(with: other.adjusted(for: self))
    }
}
