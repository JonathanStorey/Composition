// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CollectionDifference.swift
// dependencies: [Protocols/Squashable.swift]

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

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension CollectionDifference: Squashable where ChangeElement: Equatable {

    /// The difference with no changes.
    public static var identity: CollectionDifference {
        CollectionDifference([])!
    }

    /// Returns the offset at the rank among the offsets missing from the sorted list, advancing the position in the list so ascending ranks take one pass.
    private static func offset(ranked rank: Int, skipping skipped: [Int], from position: inout Int) -> Int {
        while position < skipped.count, skipped[position] <= rank + position {
            position += 1
        }
        return rank + position
    }

    /// Returns the difference that makes this difference's changes and then the next's, without inferred moves, throwing when the next removes an element this one inserted but finds a different element there.
    public func squashed(with next: CollectionDifference) throws -> CollectionDifference {
        var changes = removals.map { Change.remove(offset: $0.offset, element: $0.element, associatedWith: nil) }
        let removedOffsets = removals.map(\.offset)
        var insertion = 0
        var removed = 0
        for change in next.removals {
            while insertion < insertions.count, insertions[insertion].offset < change.offset {
                insertion += 1
            }
            if insertion < insertions.count, insertions[insertion].offset == change.offset {
                guard insertions[insertion].element == change.element else { throw CollectionDifferenceError.elementMismatch(change.offset) }
            } else {
                changes.append(.remove(offset: Self.offset(ranked: change.offset - insertion, skipping: removedOffsets, from: &removed), element: change.element, associatedWith: nil))
            }
        }
        let nextInsertedOffsets = next.insertions.map(\.offset)
        var nextRemoval = 0
        var nextInserted = 0
        for change in insertions {
            while nextRemoval < next.removals.count, next.removals[nextRemoval].offset < change.offset {
                nextRemoval += 1
            }
            guard nextRemoval == next.removals.count || next.removals[nextRemoval].offset != change.offset else { continue }
            changes.append(.insert(offset: Self.offset(ranked: change.offset - nextRemoval, skipping: nextInsertedOffsets, from: &nextInserted), element: change.element, associatedWith: nil))
        }
        changes += next.insertions.map { Change.insert(offset: $0.offset, element: $0.element, associatedWith: nil) }
        return CollectionDifference(changes)!
    }
}

/// An error thrown when a difference does not apply to a collection, carrying the offset of the change that failed.
public enum CollectionDifferenceError: Error, Equatable, Sendable {

    /// The element removed at the offset is not the element the change expects.
    case elementMismatch(Int)

    /// The offset falls outside the collection.
    case offsetOutOfBounds(Int)
}
