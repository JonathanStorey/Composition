// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/MergeStrategy.swift
// dependencies: []

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

    /// Returns the base with the insertions and removals of ours and theirs, placing ours first where both insert at one position.
    public func merged(_ ours: C, with theirs: C, from base: C) -> C {
        let base = Array(base)
        let ourEdits = edits(from: base, to: ours)
        let theirEdits = edits(from: base, to: theirs)
        var result = C()
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
        var insertions = Array(repeating: [C.Element](), count: base.count + 1)
        var position = 0
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
