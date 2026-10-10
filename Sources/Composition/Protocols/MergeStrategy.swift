// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeStrategy.swift
// dependencies: [Extensions/CollectionDifference.swift, Extensions/RangeReplaceableCollection.swift, Protocols/Mergeable.swift]

/// A way of combining two versions of a value that were each edited from a shared base.
public protocol MergeStrategy {

    /// The type of value the strategy merges.
    associatedtype Value

    /// Returns one value holding the edits that ours and theirs each made to the base, throwing if they conflict.
    func merged(_ ours: Value, with theirs: Value, from base: Value) throws -> Value
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension MergeStrategy {

    /// A strategy that merges collections element by element, keeping the insertions and removals from both sides.
    static func list<C: BidirectionalCollection & RangeReplaceableCollection>() -> Self where Self == ListStrategy<C>, C.Element: Equatable {
        ListStrategy()
    }
}

/// A strategy that merges collections element by element, keeping the insertions and removals from both sides.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ListStrategy<C: BidirectionalCollection & RangeReplaceableCollection>: MergeStrategy where C.Element: Equatable {

    /// Creates a list strategy.
    public init() {}

    /// Returns the base with the insertions and removals of ours and then theirs, placing ours first where both insert at one position.
    public func merged(_ ours: C, with theirs: C, from base: C) throws -> C {
        var result = base
        try result.apply(ours.difference(from: base).merged(with: theirs.difference(from: base)))
        return result
    }
}
