/// A mutable collection that can reorder its elements by a permutation.
public protocol PermutableCollection: MutableCollection {

    /// Moves the element at each offset in each cycle to the next offset in that cycle, wrapping from the last offset to the first.
    mutating func permute(using permutation: Permutation)
}

public extension PermutableCollection {

    /// Rotates each cycle with one `swapAt(_:_:)` per offset that does not start a cycle, which is the minimal number of swaps.
    mutating func permute(using permutation: Permutation) {
        guard let largest = permutation.cycle.max() else { return }
        precondition(largest < count, "Every offset in the cycle must be within the collection.")
        var anchor = startIndex
        var start = -1
        for offset in permutation.cycle {
            if offset > start {
                start = offset
                anchor = index(startIndex, offsetBy: offset)
            } else {
                swapAt(anchor, index(startIndex, offsetBy: offset))
            }
        }
    }
}

/// Cycles of offsets in Foata's single-line notation that apply to any collection long enough to contain them, leaving other positions in place.
public struct Permutation: Hashable, Sendable {

    /// The cycles written one after another, each starting with its largest offset, in increasing order of those starting offsets.
    public let cycle: [Int]

    /// Creates a permutation from cycles in Foata's single-line notation, or returns nil when an offset is negative or appears more than once.
    public init?(cycle: [Int]) {
        guard cycle.allSatisfy({ $0 >= 0 }), Set(cycle).count == cycle.count else { return nil }
        self.cycle = cycle
    }
}
