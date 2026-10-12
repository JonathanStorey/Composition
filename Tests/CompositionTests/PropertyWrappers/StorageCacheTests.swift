// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageCacheTests.swift
// dependencies: [PropertyWrappers/StorageCache.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct StorageCacheTests {

    @Test func decodeDecodesTheSameDataAsAnotherType() {
        let data: Data = Data("[1,2]".utf8)
        #expect(StorageCache.decode([Int].self, from: data) == [1, 2])
        #expect(StorageCache.decode([Double].self, from: data) == [1.0, 2.0])
    }

    @Test func decodeDecodesAnOptionalTypeTheFirstTime() {
        let number: Int = Int.random(in: 1_000...9_999_999)
        #expect(StorageCache.decode(Int?.self, from: Data("\(number)".utf8)) == number)
    }

    @Test func decodeReturnsNilForDataThatDoesNotDecode() {
        #expect(StorageCache.decode(Int.self, from: Data("not json".utf8)) == nil)
    }

    @Test func decodeReturnsTheSameValueForEqualData() {
        let first: [String]? = StorageCache.decode([String].self, from: Data(#"["Dune","Emma"]"#.utf8))
        let second: [String]? = StorageCache.decode([String].self, from: Data(#"["Dune","Emma"]"#.utf8))
        #expect(first == ["Dune", "Emma"])
        #expect(second == first)
    }
}
#endif
