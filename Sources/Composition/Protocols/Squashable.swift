// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Squashable.swift
// dependencies: []

/// A change that can be followed by another, where two changes in a row squash into one equivalent change.
public protocol Squashable {

    /// Returns the single change equivalent to this change followed by the next.
    func squashed(with next: Self) throws -> Self
}

public extension Squashable {

    /// Returns the single change equivalent to the first change followed by the next.
    static func squashed(_ first: Self, with next: Self) throws -> Self {
        try first.squashed(with: next)
    }

    /// Replaces this change with itself followed by the next.
    mutating func squash(with next: Self) throws {
        self = try squashed(with: next)
    }
}
