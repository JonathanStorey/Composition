// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/DiffableMergeStrategy.swift
// dependencies: [Extensions/CollectionDifference.swift, Extensions/RangeReplaceableCollection.swift, Protocols/DifferenceProtocol.swift, Protocols/MergeStrategy.swift]

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
}

/// A strategy that merges collections element by element, keeping the insertions and removals from both sides.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ListStrategy<C: BidirectionalCollection & RangeReplaceableCollection>: DiffableMergeStrategy where C.Element: Equatable {

    /// Creates a list strategy.
    public init() {}

    /// Returns the collection with the difference applied, throwing if the difference does not fit it.
    public func applying(_ difference: CollectionDifference<C.Element>, to value: C) throws -> C {
        var result: C = value
        try result.apply(difference)
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
