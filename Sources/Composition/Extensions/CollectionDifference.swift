// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CollectionDifference.swift
// dependencies: []

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension CollectionDifference.Change {

    /// The offset of the paired change when the difference has inferred moves, or `nil` otherwise.
    var associatedOffset: Int? {
        switch self {
        case .insert(_, _, let associatedOffset), .remove(_, _, let associatedOffset): associatedOffset
        }
    }

    /// The element inserted or removed.
    var element: ChangeElement {
        switch self {
        case .insert(_, let element, _), .remove(_, let element, _): element
        }
    }

    /// A Boolean value indicating whether the change inserts an element.
    var isInsertion: Bool {
        if case .insert = self { true } else { false }
    }

    /// A Boolean value indicating whether the change removes an element.
    var isRemoval: Bool {
        if case .remove = self { true } else { false }
    }

    /// The offset of the change, in the original collection for a removal and in the result for an insertion.
    var offset: Int {
        switch self {
        case .insert(let offset, _, _), .remove(let offset, _, _): offset
        }
    }
}

/// An error thrown when a difference does not apply to a collection, carrying the offset of the change that failed.
public enum CollectionDifferenceError: Error, Equatable, Sendable {

    /// The element removed at the offset is not the element the change expects.
    case elementMismatch(Int)

    /// The offset falls outside the collection.
    case offsetOutOfBounds(Int)
}
