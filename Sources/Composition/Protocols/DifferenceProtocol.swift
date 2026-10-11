// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DifferenceProtocol.swift
// dependencies: []

/// A description of how one value differs from another, listed as a sequence of changes.
public protocol DifferenceProtocol {

    /// A single change that turns one value toward another.
    associatedtype Change

    /// The changes that make up the difference, in the order they apply.
    var changes: [Change] { get }
}
