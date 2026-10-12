// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageFileTests.swift
// dependencies: [PropertyWrappers/StorageFile.swift]

#if canImport(Foundation) && canImport(os)
import Foundation
import Testing
@testable import Composition

@Suite struct StorageFileTests {

    @Test func readIsNilBeforeAnyWrite() {
        let file: StorageFile<[String: Int]> = StorageFile("CompositionTests.\(UUID().uuidString)")
        #expect(file.read() == nil)
    }

    @Test func readReturnsTheLatestWrite() {
        let file: StorageFile<[String: Int]> = StorageFile("CompositionTests.\(UUID().uuidString)")
        file.write(["a": 1])
        file.write(["a": 2, "b": 3])
        #expect(file.read() == ["a": 2, "b": 3])
    }

    @Test func readSurvivesANewInstance() {
        let name: String = "CompositionTests.\(UUID().uuidString)"
        let file: StorageFile<[Int]> = StorageFile(name)
        file.write([1, 2, 3])
        #expect(file.read() == [1, 2, 3])
        #expect(StorageFile<[Int]>(name).read() == [1, 2, 3])
    }
}
#endif
