/// A collection that reorders its elements only by swapping them, so every reorder passes through `swapAt(_:_:)`.
public protocol PermutableCollection: Collection {

    /// Moves the element at each offset in each cycle to the next offset in that cycle, wrapping from the last offset to the first.
    mutating func permute(using permutation: Permutation)

    /// Exchanges the elements at the two indices.
    mutating func swapAt(_ first: Index, _ second: Index)
}

public extension PermutableCollection {

    /// Applies the permutation with the minimal number of `swapAt(_:_:)` calls, one per offset that does not start a cycle.
    mutating func permute(using permutation: Permutation) {
        guard let largest = permutation.cycle.max() else { return }
        precondition(largest < count, "Every offset in the cycle must be within the collection.")
        permutation.forEachSwap { swapAt(index(startIndex, offsetBy: $0), index(startIndex, offsetBy: $1)) }
    }

    /// Shuffles the elements in place through a permutation shuffled directly in cycle form.
    mutating func shuffle() {
        permute(using: Permutation(shuffles: count))
    }

    /// Shuffles the elements in place through a permutation, giving the same order as `Array.shuffle(using:)` with the same generator state.
    mutating func shuffle<R: RandomNumberGenerator>(using generator: inout R) {
        var sources = Array(0..<count)
        sources.shuffle(using: &generator)
        permute(using: Permutation(sources: sources))
    }
}

/// A reordering stored as cycles in Foata's single-line notation, leaving offsets outside the cycles in place so it applies to any collection long enough.
public struct Permutation: Hashable, Sendable {

    /// The cycles written one after another, each starting with its largest offset, in increasing order of those starting offsets.
    public let cycle: [Int]

    /// Creates a permutation where `destinations[i]` is the offset the element at `i` moves to, trapping when it is not a permutation of its indices.
    public init(destinations: [Int]) {
        Permutation.validate(destinations)
        self.init(count: destinations.count, walksBackward: false) { destinations[$0] }
    }

    /// Creates a permutation where each key's element moves to its value and missing offsets stay in place, trapping when the values are not a rearrangement of the keys.
    public init(destinations: [Int: Int]) {
        Permutation.validate(destinations)
        self.init(count: (destinations.keys.max() ?? -1) + 1, walksBackward: false) { destinations[$0] ?? $0 }
    }

    /// Creates a uniformly random permutation of `0..<count` by shuffling the Foata line directly, using the system random number generator.
    public init(shuffles count: Int) {
        var generator = SystemRandomNumberGenerator()
        self.init(shuffles: count, using: &generator)
    }

    /// Creates a uniformly random permutation of `0..<count` by shuffling the Foata line directly, reproducible for a given generator state.
    public init<R: RandomNumberGenerator>(shuffles count: Int, using generator: inout R) {
        precondition(count >= 0, "The count must not be negative.")
        var line = Array(0..<count)
        line.shuffle(using: &generator)
        var kept = 0
        var largest = -1
        for position in line.indices {
            let offset = line[position]
            if offset > largest {
                largest = offset
                if position == line.count - 1 || line[position + 1] > offset { continue }
            }
            line[kept] = offset
            kept += 1
        }
        line.removeLast(line.count - kept)
        cycle = line
    }

    /// Creates a permutation where `sources[i]` is the offset whose element moves into `i`, trapping when it is not a permutation of its indices.
    public init(sources: [Int]) {
        Permutation.validate(sources)
        self.init(count: sources.count, walksBackward: true) { sources[$0] }
    }

    /// Creates a permutation where each key receives the element at its value and missing offsets stay in place, trapping when the values are not a rearrangement of the keys.
    public init(sources: [Int: Int]) {
        Permutation.validate(sources)
        self.init(count: (sources.keys.max() ?? -1) + 1, walksBackward: true) { sources[$0] ?? $0 }
    }

    /// Creates a permutation by walking each cycle of a bijection on `0..<count` from its largest offset, filling the line from the back.
    private init(count: Int, walksBackward: Bool, next: (Int) -> Int) {
        var isVisited = [Bool](repeating: false, count: count)
        var line = [Int](repeating: 0, count: count)
        var end = count
        for start in stride(from: count - 1, through: 0, by: -1) where !isVisited[start] {
            isVisited[start] = true
            var length = 1
            var offset = next(start)
            while offset != start {
                isVisited[offset] = true
                length += 1
                offset = next(offset)
            }
            guard length > 1 else { continue }
            end -= length
            line[end] = start
            offset = next(start)
            for step in 1..<length {
                line[walksBackward ? end + length - step : end + step] = offset
                offset = next(offset)
            }
        }
        cycle = Array(line[end...])
    }

    /// Traps unless the offsets contain every index of the array exactly once.
    private static func validate(_ offsets: [Int]) {
        var isUsed = [Bool](repeating: false, count: offsets.count)
        for offset in offsets {
            precondition(offsets.indices.contains(offset) && !isUsed[offset], "The offsets must contain every index exactly once.")
            isUsed[offset] = true
        }
    }

    /// Traps unless the keys are non-negative and the values are exactly the keys rearranged.
    private static func validate(_ mapping: [Int: Int]) {
        precondition(mapping.keys.allSatisfy { $0 >= 0 } && Set(mapping.values) == Set(mapping.keys), "The values must be the keys rearranged.")
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
