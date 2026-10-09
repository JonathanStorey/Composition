/// A collection that reorders its elements only by swapping them, so every reorder passes through `swapAt(_:_:)`.
public protocol PermutableCollection: Collection {

    /// Moves the element at each offset in each cycle to the next offset in that cycle, wrapping from the last offset to the first.
    mutating func permute(using permutation: Permutation)

    /// Exchanges the elements at the two indices.
    mutating func swapAt(_ i: Index, _ j: Index)
}

public extension PermutableCollection {

    /// Moves the element at the source index so it ends up at the destination index, shifting the elements between them, and returns the permutation applied.
    @discardableResult mutating func move(from source: Index, to destination: Index) -> Permutation {
        var sources = Array(0..<count)
        let offset = sources.remove(at: distance(from: startIndex, to: source))
        sources.insert(offset, at: distance(from: startIndex, to: destination))
        return permute(sources: sources)
    }

    /// Moves the elements at the given offsets to just before the element at the destination offset, keeping their relative order, and returns the permutation applied.
    @discardableResult mutating func move(fromOffsets source: some Sequence<Int>, toOffset destination: Int) -> Permutation {
        let moved = Set(source).sorted()
        precondition(moved.allSatisfy { (0..<count).contains($0) } && (0...count).contains(destination), "Every offset must be within the collection.")
        var isMoved = [Bool](repeating: false, count: count)
        for offset in moved {
            isMoved[offset] = true
        }
        var before: [Int] = []
        var after: [Int] = []
        for offset in 0..<count where !isMoved[offset] {
            if offset < destination {
                before.append(offset)
            } else {
                after.append(offset)
            }
        }
        return permute(sources: before + moved + after)
    }

    /// Moves the elements that satisfy the predicate after those that do not, keeping the relative order within each group, and returns the index of the first moved element.
    @discardableResult mutating func partition(by belongsInSecondPartition: (Element) throws -> Bool) rethrows -> Index {
        var first: [Int] = []
        var second: [Int] = []
        for (offset, element) in enumerated() {
            if try belongsInSecondPartition(element) {
                second.append(offset)
            } else {
                first.append(offset)
            }
        }
        permute(using: Permutation(sources: first + second))
        return index(startIndex, offsetBy: first.count)
    }

    /// Applies the permutation with the minimal number of `swapAt(_:_:)` calls, walking the indices once so each swap is O(1), which requires `swapAt(_:_:)` to keep indices valid.
    mutating func permute(using permutation: Permutation) {
        guard !permutation.cycle.isEmpty else { return }
        precondition(permutation.minimumCount <= count, "Every offset in the cycle must be within the collection.")
        let positions = Array(indices.prefix(permutation.minimumCount))
        permutation.forEachSwap { swapAt(positions[$0], positions[$1]) }
    }

    /// Reverses the elements in place and returns the permutation applied.
    @discardableResult mutating func reverse() -> Permutation {
        permute(returning: Permutation(reversing: count))
    }

    /// Rotates the elements so the element at the given index becomes the first, and returns the permutation applied.
    @discardableResult mutating func rotate(toStartAt newStart: Index) -> Permutation {
        permute(returning: Permutation(rotating: count, by: distance(from: startIndex, to: newStart)))
    }

    /// Shuffles the elements in place through a permutation shuffled directly in cycle form, and returns the permutation applied.
    @discardableResult mutating func shuffle() -> Permutation {
        permute(returning: Permutation(shuffles: count))
    }

    /// Shuffles the elements in place, giving the same order as `Array.shuffle(using:)` with the same generator state, and returns the permutation applied.
    @discardableResult mutating func shuffle<R: RandomNumberGenerator>(using generator: inout R) -> Permutation {
        var sources = Array(0..<count)
        sources.shuffle(using: &generator)
        return permute(sources: sources)
    }

    /// Sorts the elements in place through a single permutation applied with one swap per element that moves within a cycle, and returns the permutation applied.
    @discardableResult mutating func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> Permutation {
        let elements = Array(self)
        return try permute(sources: elements.indices.sorted { try areInIncreasingOrder(elements[$0], elements[$1]) })
    }

    /// Applies the permutation and returns it.
    private mutating func permute(returning permutation: Permutation) -> Permutation {
        permute(using: permutation)
        return permutation
    }

    /// Applies the permutation built from source offsets and returns it.
    private mutating func permute(sources: [Int]) -> Permutation {
        permute(returning: Permutation(sources: sources))
    }
}

public extension PermutableCollection where Element: Comparable {

    /// Sorts the elements in ascending order through a single permutation, and returns the permutation applied.
    @discardableResult mutating func sort() -> Permutation {
        sort(by: <)
    }
}

public extension PermutableCollection where Self: RandomAccessCollection {

    /// Applies the permutation with the minimal number of `swapAt(_:_:)` calls, offsetting each index directly in O(1).
    mutating func permute(using permutation: Permutation) {
        guard !permutation.cycle.isEmpty else { return }
        precondition(permutation.minimumCount <= count, "Every offset in the cycle must be within the collection.")
        permutation.forEachSwap { swapAt(index(startIndex, offsetBy: $0), index(startIndex, offsetBy: $1)) }
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

    /// Creates the permutation that reverses `0..<count`, writing each swapped pair directly with its larger offset first.
    fileprivate init(reversing count: Int) {
        var line: [Int] = []
        line.reserveCapacity(count)
        for offset in (0..<(count / 2)).reversed() {
            line.append(count - 1 - offset)
            line.append(offset)
        }
        cycle = line
    }

    /// Creates the permutation that moves the element at offset `shift` to the front of `0..<count`, writing one cycle per residue class modulo the greatest common divisor.
    fileprivate init(rotating count: Int, by shift: Int) {
        guard count > 0, shift % count != 0 else {
            cycle = []
            return
        }
        let step = (shift % count + count) % count
        var divisor = count
        var remainder = step
        while remainder != 0 {
            (divisor, remainder) = (remainder, divisor % remainder)
        }
        var line: [Int] = []
        line.reserveCapacity(count)
        for start in (count - divisor)..<count {
            var offset = start
            repeat {
                line.append(offset)
                offset = offset >= step ? offset - step : offset + count - step
            } while offset != start
        }
        cycle = line
    }

    /// Creates a permutation where `sources[i]` is the offset whose element moves into `i`, writing each cycle from the back in one walk without validating the mapping.
    fileprivate init(sources: [Int]) {
        var isVisited = [Bool](repeating: false, count: sources.count)
        var line = [Int](repeating: 0, count: sources.count)
        var end = sources.count
        for start in sources.indices.reversed() where !isVisited[start] {
            isVisited[start] = true
            var offset = sources[start]
            guard offset != start else { continue }
            while offset != start {
                isVisited[offset] = true
                end -= 1
                line[end] = offset
                offset = sources[offset]
            }
            end -= 1
            line[end] = start
        }
        line.removeSubrange(..<end)
        cycle = line
    }

    /// Creates a permutation from a line already in Foata's single-line notation.
    private init(cycle: [Int]) {
        self.cycle = cycle
    }

    /// The permutation that undoes this one, made by reversing each cycle after its largest offset.
    public var inverted: Permutation {
        var line = cycle
        var blockStart = 0
        var largest = -1
        for position in line.indices where line[position] > largest {
            largest = line[position]
            if position > blockStart + 1 { line[(blockStart + 1)..<position].reverse() }
            blockStart = position
        }
        if line.count > blockStart + 1 { line[(blockStart + 1)...].reverse() }
        return Permutation(cycle: line)
    }

    /// The smallest collection count this permutation can be applied to, one more than its largest offset.
    public var minimumCount: Int {
        (cycle.max() ?? -1) + 1
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
