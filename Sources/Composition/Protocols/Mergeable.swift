// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Mergeable.swift
// dependencies: [Protocols/Shiftable.swift, Protocols/Squashable.swift]

/// A value that can combine with another made independently, into one value holding both.
public protocol Mergeable {

    /// Returns one value holding both this value and the other, where neither was made from the other.
    func merged(with other: Self) throws -> Self
}

public extension Mergeable {

    /// Returns one value holding both the first value and the other, where neither was made from the other.
    static func merged(_ first: Self, with other: Self) throws -> Self {
        try first.merged(with: other)
    }

    /// Combines the other value, made independently, into this one.
    mutating func merge(with other: Self) throws {
        self = try merged(with: other)
    }
}

public extension Mergeable where Self: Shiftable & Squashable {

    /// Returns this change followed by the other change moved to apply after it.
    func merged(with other: Self) throws -> Self {
        try squashed(with: other.shifted(by: self))
    }
}
