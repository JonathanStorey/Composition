// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategy.swift
// dependencies: [Protocols/DifferenceProtocol.swift, Protocols/MergeStrategy.swift, Protocols/Mergeable.swift]

/// A strategy that both finds differences and merges values.
public typealias DiffableMergeStrategy = DiffStrategy & MergeStrategy

/// A way of finding how one value differs from another and applying that difference back.
public protocol DiffStrategy<Value> {

    /// The type of difference the strategy produces.
    associatedtype Difference: DifferenceProtocol

    /// The type of value the strategy compares.
    associatedtype Value

    /// Returns the value with the difference applied, throwing if the difference does not fit it.
    func applying(_ difference: Difference, to value: Value) throws -> Value

    /// Returns the difference that turns the original value into the updated one.
    func difference(from original: Value, to updated: Value) -> Difference
}

public extension MergeStrategy where Self: DiffStrategy, Difference: Mergeable {

    /// Returns the base with the merged differences of ours and theirs applied, throwing if they conflict.
    func merged(_ ours: Value, with theirs: Value, from base: Value) throws -> Value {
        let combined: Difference = try difference(from: base, to: ours).merged(with: difference(from: base, to: theirs))
        return try applying(combined, to: base)
    }
}
