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

// needs description
public struct Permutation: Hashable, Sendable {

    /// The cycles written Foata's single-line notation.
    public let cycle: [Int]

    /// Creates a permutation from a mapping input with a mathematically efficient conversion to cycles -- does not recreate the order
    public init(mapping: [Int:Int], direction: MappingDirection) {}

    /// Creates a permutation from a mapping input with a mathematically efficient conversion to cycles -- does not recreate the order
    public init(mapping: [Int], direction: MappingDirection) {}

    /// Creates a permutation by a random shuffle -- it shuffles the components of the cycle rather than randomly shuffling objects
    public init(shuffles count: Int) {}
    
    /// Creates a permutation from cycles in Foata's single-line notation, or returns nil when an offset is negative or appears more than once.
    private init?(cycle: [Int]) {
        guard cycle.allSatisfy({ $0 >= 0 }), Set(cycle).count == cycle.count else { return nil }
        self.cycle = cycle
    }

    /// Calls the closure with each pair of offsets to swap, in order, deriving them in one pass with no allocation.
    fileprivate func forEachSwap(_ body: (Int, Int) throws -> Void) rethrows {
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

extension Permutation {

    enum MappingDirection {
        case forward
        case reverse
}
