// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorageTests.swift
// dependencies: [Extensions/FileManager.swift, PropertyWrappers/FileStorage.swift, Protocols/FileRepresentable.swift]

// MARK: - Foundation + Observation + os + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(UniformTypeIdentifiers)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct FileStorageTests {

    #if compiler(>=6.2) && os(macOS)
    @Test func absolutePathStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = FileStorage<Int>(wrappedValue: 0, "/theme", .temp) }
    }
    #endif

    @Test func cachesKeepTheValue() {
        let storage: FileStorage<String> = FileStorage(wrappedValue: "", UUID().uuidString, .caches)
        storage.wrappedValue = "Dune"
        #expect(storage.wrappedValue == "Dune")
    }

    @Test func documentsHoldAnyValue() {
        let data: FileStorage<Data?> = FileStorage("\(UUID().uuidString).png", .documents)
        let number: FileStorage<Int?> = FileStorage(UUID().uuidString, .documents)
        #expect(data.wrappedValue == nil)
        #expect(number.wrappedValue == nil)
    }

    #if os(macOS)
    @Test func iCloudDriveKeepsDataOnTheDeviceWithoutAnAccount() {
        let storage: FileStorage<Data> = FileStorage(wrappedValue: Data(), "\(UUID().uuidString).pdf", .iCloudDrive)
        storage.wrappedValue = Data([4])
        #expect(storage.wrappedValue == Data([4]))
    }

    @Test func iCloudKeepsTheFileOnTheDeviceWithoutAnAccount() {
        let storage: FileStorage<Int> = FileStorage(wrappedValue: 0, UUID().uuidString, .iCloud)
        storage.wrappedValue = 4
        #expect(storage.wrappedValue == 4)
    }
    #endif

    #if compiler(>=6.2) && os(macOS)
    @Test func pathWithHiddenNameStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = FileStorage<Int>(wrappedValue: 0, "Settings/.theme", .temp) }
    }

    @Test func pathWithParentFolderStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = FileStorage<Int>(wrappedValue: 0, "../theme", .temp) }
    }
    #endif

    @Test func wrappedValueAddsTheDefaultExtensionWhenOnlyAFolderHasADot() {
        let path: String = "Exports.2026/\(UUID().uuidString)"
        let storage: FileStorage<[Int]> = FileStorage(wrappedValue: [], path, .temp)
        storage.wrappedValue = [3]
        FileManager.CachedFile.flush()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: "\(path).json"))) == Data("[3]".utf8))
    }

    @Test func wrappedValueChangeNotifiesObservers() async {
        let storage: FileStorage<Int?> = FileStorage(UUID().uuidString, .temp)
        await confirmation { changed in
            withObservationTracking({ _ = storage.wrappedValue }, onChange: { changed() })
            storage.wrappedValue = 1
        }
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        #expect(FileStorage(wrappedValue: 7, UUID().uuidString, .temp).wrappedValue == 7)
    }

    @Test func wrappedValueIsSharedByEveryWrapperForTheFile() {
        let path: String = "Shared/\(UUID().uuidString)"
        let first: FileStorage<String> = FileStorage(wrappedValue: "", path, .temp)
        let second: FileStorage<String> = FileStorage(wrappedValue: "", path, .temp)
        first.wrappedValue = "Dune"
        #expect(second.wrappedValue == "Dune")
    }

    @Test func wrappedValueKeepsAStringAsText() {
        let path: String = UUID().uuidString
        let storage: FileStorage<String> = FileStorage(wrappedValue: "", path, .temp)
        storage.wrappedValue = "Dune"
        FileManager.CachedFile.flush()
        #expect((try? String(contentsOf: URL.temporaryDirectory.appending(path: "\(path).txt"), encoding: .utf8)) == "Dune")
    }

    @Test func wrappedValueKeepsAStringAsTextUnderAnyExtension() {
        let path: String = "\(UUID().uuidString).json"
        let storage: FileStorage<String?> = FileStorage(path, .temp)
        storage.wrappedValue = "# Dune"
        FileManager.CachedFile.flush()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: path))) == Data("# Dune".utf8))
    }

    @Test func wrappedValueKeepsDataAsIs() {
        let path: String = "\(UUID().uuidString).png"
        let storage: FileStorage<Data?> = FileStorage(path, .temp)
        storage.wrappedValue = Data([1, 2, 3])
        FileManager.CachedFile.flush()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: path))) == Data([1, 2, 3]))
    }

    @Test func wrappedValueKeepsDataUnderTheDataExtensionByDefault() {
        let path: String = UUID().uuidString
        let storage: FileStorage<Data?> = FileStorage(path, .temp)
        storage.wrappedValue = Data([5])
        FileManager.CachedFile.flush()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: "\(path).data"))) == Data([5]))
    }

    @Test func wrappedValueKeepsJSONUnderTheGivenExtension() {
        let path: String = "\(UUID().uuidString).txt"
        let storage: FileStorage<[Int]> = FileStorage(wrappedValue: [], path, .temp)
        storage.wrappedValue = [3]
        FileManager.CachedFile.flush()
        #expect((try? Data(contentsOf: URL.temporaryDirectory.appending(path: path))) == Data("[3]".utf8))
    }

    @Test func wrappedValueRemovesTheFileWhenSetToNil() {
        let path: String = UUID().uuidString
        let storage: FileStorage<[String]?> = FileStorage(path, .temp)
        storage.wrappedValue = ["Dune", "Emma"]
        FileManager.CachedFile.flush()
        #expect(FileManager.default.fileExists(atPath: URL.temporaryDirectory.appending(path: "\(path).json").path(percentEncoded: false)))
        storage.wrappedValue = nil
        FileManager.CachedFile.flush()
        #expect(storage.wrappedValue == nil)
        #expect(!FileManager.default.fileExists(atPath: URL.temporaryDirectory.appending(path: "\(path).json").path(percentEncoded: false)))
    }

    @Test func wrappedValueWritesJSONInTheBackground() {
        let path: String = "Nested/Folder/\(UUID().uuidString)"
        let storage: FileStorage<[Int]> = FileStorage(wrappedValue: [], path, .temp)
        storage.wrappedValue = [1, 2]
        FileManager.CachedFile.flush()
        let data: Data? = try? Data(contentsOf: URL.temporaryDirectory.appending(path: "\(path).json"))
        #expect(data.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } == [1, 2])
    }
}
#endif

// MARK: - Foundation + Observation + os + SwiftUI + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

extension FileStorageTests {

    @Test func projectedValueWritesThrough() {
        let storage: FileStorage<Bool> = FileStorage(wrappedValue: false, UUID().uuidString, .temp)
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
