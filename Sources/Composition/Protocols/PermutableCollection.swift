/// A collection that reorders its elements only by swapping them, so every reorder passes through `swapAt(_:_:)`.
public protocol PermutableCollection: Collection {

    /// Moves the element at each offset in each cycle to the next offset in that cycle, wrapping from the last offset to the first.
    mutating func permute(using permutation: Permutation)

    /// Exchanges the elements at the two indices.
    mutating func swapAt(_ i: Index, _ j: Index)
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

    /// Creates a uniformly random permutation of `0..<count` by shuffling the Foata line directly.
    public init(shuffles count: Int) {
        precondition(count >= 0, "The count must not be negative.")
        var line = Array(0..<count)
        line.shuffle()
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

    /// Creates a permutation where `sources[i]` is the offset whose element moves into `i`, walking each cycle from its largest offset and filling the line from the back without validating the mapping.
    fileprivate init(sources: [Int]) {
        var isVisited = [Bool](repeating: false, count: sources.count)
        var line = [Int](repeating: 0, count: sources.count)
        var end = sources.count
        for start in sources.indices.reversed() where !isVisited[start] {
            isVisited[start] = true
            var length = 1
            var offset = sources[start]
            while offset != start {
                isVisited[offset] = true
                length += 1
                offset = sources[offset]
            }
            guard length > 1 else { continue }
            end -= length
            line[end] = start
            offset = sources[start]
            for step in 1..<length {
                line[end + length - step] = offset
                offset = sources[offset]
            }
        }
        cycle = Array(line[end...])
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
