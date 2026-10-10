// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategy.swift
// dependencies: [Extensions/CollectionDifference.swift, Protocols/DifferenceProtocol.swift, Protocols/MergeStrategy.swift, Protocols/Mergeable.swift]

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

public extension MergeStrategy {

    /// A strategy that merges collections element by element, keeping the insertions and removals from both sides.
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    static func list<C: BidirectionalCollection & RangeReplaceableCollection>() -> Self where Self == ListStrategy<C>, C.Element: Equatable {
        ListStrategy()
    }

    /// A strategy that keeps whichever side changed the value, throwing if both changed it differently.
    static func replace<V: Equatable>() -> Self where Self == ReplaceStrategy<V> {
        ReplaceStrategy()
    }
}

public extension MergeStrategy where Self: DiffStrategy, Difference: Mergeable {

    /// Returns the base with the merged differences of ours and theirs applied, throwing if they conflict.
    func merged(_ ours: Value, with theirs: Value, from base: Value) throws -> Value {
        let combined: Difference = try difference(from: base, to: ours).merged(with: difference(from: base, to: theirs))
        return try applying(combined, to: base)
    }
}

/// A strategy that merges collections element by element, keeping the insertions and removals from both sides.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ListStrategy<C: BidirectionalCollection & RangeReplaceableCollection>: DiffableMergeStrategy where C.Element: Equatable {

    /// Creates a list strategy.
    public init() {}

    /// Returns the collection with the difference applied, throwing if the difference does not fit it.
    public func applying(_ difference: CollectionDifference<C.Element>, to value: C) throws -> C {
        guard let result: C = value.applying(difference) else { throw MergeStrategyError.conflict }
        return result
    }

    /// Returns the insertions and removals that turn the original collection into the updated one.
    public func difference(from original: C, to updated: C) -> CollectionDifference<C.Element> {
        updated.difference(from: original)
    }

    /// Returns the base with the insertions and removals of ours and theirs, placing ours first where both insert at one position.
    public func merged(_ ours: C, with theirs: C, from base: C) -> C {
        let base: [C.Element] = Array(base)
        let ourEdits: (insertions: [[C.Element]], removals: Set<Int>) = edits(from: base, to: ours)
        let theirEdits: (insertions: [[C.Element]], removals: Set<Int>) = edits(from: base, to: theirs)
        var result: C = C()
        for position in 0...base.count {
            result.append(contentsOf: ourEdits.insertions[position])
            result.append(contentsOf: theirEdits.insertions[position])
            if position < base.count, !ourEdits.removals.contains(position), !theirEdits.removals.contains(position) {
                result.append(base[position])
            }
        }
        return result
    }

    /// Returns the offsets of the base elements the edit removed and, for each base position, the elements it inserted before that position.
    private func edits(from base: [C.Element], to edited: C) -> (insertions: [[C.Element]], removals: Set<Int>) {
        var insertedOffsets: Set<Int> = []
        var removals: Set<Int> = []
        for change in edited.difference(from: base) {
            switch change {
            case let .insert(offset, _, _):
                insertedOffsets.insert(offset)
            case let .remove(offset, _, _):
                removals.insert(offset)
            }
        }
        var insertions: [[C.Element]] = Array(repeating: [], count: base.count + 1)
        var position: Int = 0
        for (offset, element) in edited.enumerated() {
            while removals.contains(position) {
                position += 1
            }
            if insertedOffsets.contains(offset) {
                insertions[position].append(element)
            } else {
                position += 1
            }
        }
        return (insertions, removals)
    }
}

/// A strategy that keeps whichever side changed the value, throwing if both changed it differently.
public struct ReplaceStrategy<V: Equatable>: DiffableMergeStrategy {

    /// Creates a replace strategy.
    public init() {}

    /// Returns the replacement value, or the value itself when the replacement is unchanged.
    public func applying(_ difference: Replacement<V>, to value: V) -> V {
        difference.changes.last ?? value
    }

    /// Returns a replacement with the updated value, or an unchanged replacement when the values are equal.
    public func difference(from original: V, to updated: V) -> Replacement<V> {
        original == updated ? Replacement() : Replacement(updated)
    }
}

/// A difference that replaces a value with a new one, or leaves it unchanged.
public struct Replacement<V: Equatable>: DifferenceProtocol, Equatable, Mergeable {

    /// The new value, or no values when the replacement leaves the value unchanged.
    public let changes: [V]

    /// Creates a replacement that leaves the value unchanged.
    public init() {
        changes = []
    }

    /// Creates a replacement that sets the value.
    public init(_ value: V) {
        changes = [value]
    }

    /// Returns the replacement that keeps both sides' changes, throwing if each sets a different value.
    public func merged(with other: Replacement) throws -> Replacement {
        if changes.isEmpty || changes == other.changes {
            return other
        }
        guard other.changes.isEmpty else { throw MergeStrategyError.conflict }
        return self
    }
}
