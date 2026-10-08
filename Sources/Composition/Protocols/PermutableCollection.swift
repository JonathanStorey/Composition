/// A mutable collection that can reorder its elements by a permutation.
public protocol PermutableCollection: MutableCollection {

    /// Moves the element at each offset in the cycle to the next offset, and the element at the last offset to the first.
    mutating func permute(using permutation: Permutation)
}

public extension PermutableCollection {

    /// Rotates the elements around the cycle with one `swapAt(_:_:)` per offset after the first.
    mutating func permute(using permutation: Permutation) {
        guard let first = permutation.cycle.first, let last = permutation.cycle.max() else { return }
        precondition(last < count, "Every offset in the cycle must be within the collection.")
        let anchor = index(startIndex, offsetBy: first)
        for offset in permutation.cycle.dropFirst() {
            swapAt(anchor, index(startIndex, offsetBy: offset))
        }
    }
}

/// A single cycle of offsets that applies to any collection long enough to contain them, leaving other positions in place.
public struct Permutation: Hashable, Sendable {

    /// The offsets in cycle order, where the element at each offset moves to the next one.
    public let cycle: [Int]

    /// Creates a permutation from a cycle, or returns nil when an offset is negative or appears more than once.
    public init?(cycle: [Int]) {
        guard cycle.allSatisfy({ $0 >= 0 }), Set(cycle).count == cycle.count else { return nil }
        self.cycle = cycle
    }
}
