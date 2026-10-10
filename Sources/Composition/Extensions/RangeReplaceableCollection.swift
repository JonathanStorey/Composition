// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/RangeReplaceableCollection.swift
// dependencies: [Extensions/CollectionDifference.swift]

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension RangeReplaceableCollection {

    /// Applies the difference in place, throwing and leaving the collection unchanged if a change falls outside it.
    mutating func apply(_ difference: CollectionDifference<Element>) throws {
        self = try applying(difference, matching: nil)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension RangeReplaceableCollection where Element: Equatable {

    /// Applies the difference in place, throwing and leaving the collection unchanged if a change falls outside it or removes a different element.
    mutating func apply(_ difference: CollectionDifference<Element>) throws {
        self = try applying(difference, matching: { $0 == $1 })
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private extension RangeReplaceableCollection {

    /// Returns the collection with the removals and then the insertions applied, walking each collection once and checking removed elements with the closure when one is given.
    func applying(_ difference: CollectionDifference<Element>, matching areEqual: ((Element, Element) -> Bool)?) throws -> Self {
        var kept: Self = Self()
        var index: Index = startIndex
        var offset: Int = 0
        for removal in difference.removals {
            guard let removed = self.index(index, offsetBy: removal.offset - offset, limitedBy: endIndex), removed != endIndex else { throw CollectionDifferenceError.offsetOutOfBounds(removal.offset) }
            if let areEqual, !areEqual(self[removed], removal.element) { throw CollectionDifferenceError.elementMismatch(removal.offset) }
            kept.append(contentsOf: self[index..<removed])
            index = self.index(after: removed)
            offset = removal.offset + 1
        }
        kept.append(contentsOf: self[index...])
        var result: Self = Self()
        var keptIndex: Index = kept.startIndex
        var placed: Int = 0
        for insertion in difference.insertions {
            guard let inserted = kept.index(keptIndex, offsetBy: insertion.offset - placed, limitedBy: kept.endIndex) else { throw CollectionDifferenceError.offsetOutOfBounds(insertion.offset) }
            result.append(contentsOf: kept[keptIndex..<inserted])
            result.append(insertion.element)
            keptIndex = inserted
            placed = insertion.offset + 1
        }
        result.append(contentsOf: kept[keptIndex...])
        return result
    }
}
