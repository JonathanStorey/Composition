// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorageTests.swift
// dependencies: [PropertyWrappers/FileStorage.swift]

// MARK: - Foundation + Observation + os

#if canImport(Foundation) && canImport(Observation) && canImport(os)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct FileStorageTests {

    #if os(macOS)
    @Test func iCloudKeepsTheFileOnTheDeviceWithoutAnAccount() {
        let storage: FileStorage<Int> = FileStorage(wrappedValue: 0, "\(UUID().uuidString).json", .iCloud)
        storage.wrappedValue = 4
        #expect(storage.wrappedValue == 4)
    }
    #endif

    @Test func pathViolationAllowsRelativeFilePaths() {
        #expect(StoredFile.pathViolation("theme.json") == nil)
        #expect(StoredFile.pathViolation("Settings/Colors/theme.json") == nil)
    }

    @Test func pathViolationCatchesPathsThatLeaveTheLocation() {
        for path: String in ["", "/theme.json", "Settings/", "Settings//theme.json", "../theme.json", "Settings/./theme.json"] {
            #expect(StoredFile.pathViolation(path) != nil)
        }
    }

    #if compiler(>=6.2) && os(macOS)
    @Test func pathWithParentFolderStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = FileStorage<Int>(wrappedValue: 0, "../theme.json", .temp) }
    }
    #endif

    @Test func wrappedValueChangeNotifiesObservers() async {
        let storage: FileStorage<Int?> = FileStorage("\(UUID().uuidString).json", .temp)
        await confirmation { changed in
            withObservationTracking({ _ = storage.wrappedValue }, onChange: { changed() })
            storage.wrappedValue = 1
        }
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        #expect(FileStorage(wrappedValue: 7, "\(UUID().uuidString).json", .temp).wrappedValue == 7)
    }

    @Test func wrappedValueIsSharedByEveryWrapperForTheFile() {
        let path: String = "Shared/\(UUID().uuidString).json"
        let first: FileStorage<String> = FileStorage(wrappedValue: "", path, .temp)
        let second: FileStorage<String> = FileStorage(wrappedValue: "", path, .temp)
        first.wrappedValue = "Dune"
        #expect(second.wrappedValue == "Dune")
    }

    @Test func wrappedValueKeepsDataAsIs() {
        let path: String = "\(UUID().uuidString).png"
        let storage: FileStorage<Data?> = FileStorage(path, .temp)
        storage.wrappedValue = Data([1, 2, 3])
        StoredFile.flushAll()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: path))) == Data([1, 2, 3]))
    }

    @Test func wrappedValueReloadsWhenTheFileChangesOnDisk() async throws {
        let path: String = "\(UUID().uuidString).json"
        let storage: FileStorage<Int> = FileStorage(wrappedValue: 0, path, .temp)
        #expect(storage.wrappedValue == 0)
        try Data("9".utf8).write(to: URL.temporaryDirectory.appending(path: path), options: .atomic)
        for _ in 0..<60 where storage.wrappedValue != 9 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(storage.wrappedValue == 9)
    }

    @Test func wrappedValueRemovesTheFileWhenSetToNil() {
        let path: String = "\(UUID().uuidString).json"
        let storage: FileStorage<[String]?> = FileStorage(path, .temp)
        storage.wrappedValue = ["Dune", "Emma"]
        StoredFile.flushAll()
        #expect(FileManager.default.fileExists(atPath: URL.temporaryDirectory.appending(path: path).path(percentEncoded: false)))
        storage.wrappedValue = nil
        StoredFile.flushAll()
        #expect(storage.wrappedValue == nil)
        #expect(!FileManager.default.fileExists(atPath: URL.temporaryDirectory.appending(path: path).path(percentEncoded: false)))
    }

    @Test func wrappedValueWritesJSONInTheBackground() {
        let path: String = "Nested/Folder/\(UUID().uuidString).json"
        let storage: FileStorage<[Int]> = FileStorage(wrappedValue: [], path, .temp)
        storage.wrappedValue = [1, 2]
        StoredFile.flushAll()
        let data: Data? = try? Data(contentsOf: URL.temporaryDirectory.appending(path: path))
        #expect(data.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } == [1, 2])
    }
}
#endif

// MARK: - Foundation + Observation + os + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(SwiftUI)
import SwiftUI

extension FileStorageTests {

    @Test func projectedValueWritesThrough() {
        let storage: FileStorage<Bool> = FileStorage(wrappedValue: false, "\(UUID().uuidString).json", .temp)
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
