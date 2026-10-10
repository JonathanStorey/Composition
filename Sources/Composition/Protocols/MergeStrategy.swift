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

public extension MergeStrategy {

    /// A strategy that keeps whichever side changed the value, throwing if both changed it differently.
    static func replace<V: Equatable>() -> Self where Self == ReplaceStrategy<V> {
        ReplaceStrategy()
    }
}

/// A strategy that keeps whichever side changed the value, throwing if both changed it differently.
public struct ReplaceStrategy<V: Equatable>: MergeStrategy {

    /// Creates a replace strategy.
    public init() {}

    /// Returns the side that changed the base, or either side when both made the same change, throwing when they changed it differently.
    public func merged(_ ours: V, with theirs: V, from base: V) throws -> V {
        if ours == base || ours == theirs {
            return theirs
        }
        guard theirs == base else { throw MergeStrategyError.conflict }
        return ours
    }
}

/// An error thrown when a strategy cannot combine the two sides of a merge.
public enum MergeStrategyError: Error, Equatable, Sendable {

    /// Both sides changed the value in ways the strategy cannot combine.
    case conflict
}
