// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Patchable.swift
// dependencies: []

/// A value that can describe how it differs from another value as a patch and apply such a patch to itself.
public protocol Patchable {

    /// The change that turns one value into another.
    associatedtype Patch

    /// Returns the patch that turns the base into this value.
    func difference(from base: Self) -> Patch

    /// Applies the patch in place, throwing and leaving the value unchanged if the patch does not fit it.
    mutating func apply(_ patch: Patch) throws
}
