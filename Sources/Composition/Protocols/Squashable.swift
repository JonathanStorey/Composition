// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Squashable.swift
// dependencies: []

/// A change that can be followed by another, where two changes in a row squash into one equivalent change.
public protocol Squashable {

    /// The change that does nothing, so squashing it with another change returns that change.
    static var identity: Self { get }

    /// Returns the single change equivalent to this change followed by the next.
    func squashed(with next: Self) throws -> Self
}

public extension Squashable {

    /// Returns the single change equivalent to the changes applied in order, or `identity` when there are none.
    static func squashed<S: Sequence>(inOrder changes: S) throws -> Self where S.Element == Self {
        try changes.reduce(identity) { try $0.squashed(with: $1) }
    }

    /// Replaces this change with itself followed by the next.
    mutating func squash(with next: Self) throws {
        self = try squashed(with: next)
    }
}
