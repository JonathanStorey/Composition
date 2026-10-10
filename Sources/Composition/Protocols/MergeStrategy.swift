// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeStrategy.swift
// dependencies: []

/// A way of combining two versions of a value that were each edited from a shared base.
public protocol MergeStrategy<Value> {

    /// The type of value the strategy merges.
    associatedtype Value

    /// Returns one value holding the edits that ours and theirs each made to the base, throwing if they conflict.
    func merged(_ ours: Value, with theirs: Value, from base: Value) throws -> Value
}

/// An error thrown when a strategy cannot combine the two sides of a merge.
public enum MergeStrategyError: Error, Equatable, Sendable {

    /// Both sides changed the value in ways the strategy cannot combine.
    case conflict
}
