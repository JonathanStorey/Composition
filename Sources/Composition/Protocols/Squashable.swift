// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Squashable.swift
// dependencies: []

/// A change that can be followed by another made from its result, where the two in a row squash into one equivalent change.
public protocol Squashable {

    /// Returns the single change equivalent to this change followed by the next, where the next was made from this change's result.
    func squashed(with next: Self) throws -> Self
}

public extension Squashable {

    /// Returns the single change equivalent to the first change followed by the next, where the next was made from the first's result.
    static func squashed(_ first: Self, with next: Self) throws -> Self {
        try first.squashed(with: next)
    }

    /// Replaces this change with itself followed by the next, where the next was made from this change's result.
    mutating func squash(with next: Self) throws {
        self = try squashed(with: next)
    }
}
