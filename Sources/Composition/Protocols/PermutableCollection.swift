/// A mutable collection that can reorder its elements by a permutation.
public protocol PermutableCollection: MutableCollection {

    /// Moves the element at each offset in each cycle to the next offset in that cycle, wrapping from the last offset to the first.
    mutating func permute(using permutation: Permutation)
}

public extension PermutableCollection {

    /// Applies the permutation with the minimal number of `swapAt(_:_:)` calls, one per offset that does not start a cycle.
    mutating func permute(using permutation: Permutation) {
        guard let largest = permutation.cycle.max() else { return }
        precondition(largest < count, "Every offset in the cycle must be within the collection.")
        permutation.forEachSwap { swapAt(index(startIndex, offsetBy: $0), index(startIndex, offsetBy: $1)) }
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

    /// Calls the closure with each pair of offsets to swap, in order, deriving them in one pass with no allocation.
    public func forEachSwap(_ body: (Int, Int) throws -> Void) rethrows {
        var start = -1
        for offset in cycle {
            if offset > start {
                start = offset
            } else {
                try body(start, offset)
            }
        }
    }
}
