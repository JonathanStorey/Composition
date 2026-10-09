// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/Array.swift
// dependencies: [Extensions/RangeReplaceableCollection.swift, Protocols/Patchable.swift]

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Array: Patchable where Element: Equatable {

    /// Returns the difference that turns the base array into this array.
    public func difference(from base: [Element]) -> CollectionDifference<Element> {
        difference(from: base, by: ==)
    }
}
