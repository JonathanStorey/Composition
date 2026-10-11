// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DifferenceProtocol.swift
// dependencies: []

/// A description of how one value differs from another, as a collection of changes in the order they apply.
public protocol DifferenceProtocol<ChangeElement>: Collection where Element == Change {

    /// The type of value each change inserts or removes.
    associatedtype ChangeElement

    /// A single change that turns one value toward another.
    associatedtype Change
}
