// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/FileManagerTests.swift
// dependencies: [Extensions/FileManager.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct FileManagerTests {

    @Test func contentsReadsTheFile() throws {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data("Dune".utf8).write(to: url)
        #expect(try FileManager.default.contents(at: url) == Data("Dune".utf8))
    }

    @Test func contentsThrowsWithoutAFile() {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        #expect(throws: (any Error).self) { try FileManager.default.contents(at: url) }
    }

    @Test func localFolderForICloudDriveIsTheDocumentsFolderOfTheDeviceCopy() {
        #expect(FileManager.default.localFolder(for: .iCloudDrive) == FileManager.default.localFolder(for: .iCloud).appending(component: "Documents", directoryHint: .isDirectory))
    }

    @Test func localFolderIsTheLocationsFolderOutsideICloud() {
        #expect(FileManager.default.localFolder(for: .caches) == FileManager.default.url(for: .caches))
    }

    @Test func moveItemToICloudLeavesAFileICloudAlreadyHas() throws {
        let local: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        let destination: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data("Dune".utf8).write(to: local)
        try Data("Emma".utf8).write(to: destination)
        #expect(try !FileManager.default.moveItemToICloud(at: local, to: destination))
        #expect(try Data(contentsOf: destination) == Data("Emma".utf8))
    }

    @Test func moveItemToICloudSkipsAMissingFile() throws {
        let local: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        let destination: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        #expect(try !FileManager.default.moveItemToICloud(at: local, to: destination))
    }

    @Test func urlForAppIsTheAppsFolderInApplicationSupport() {
        let folder: URL = URL.applicationSupportDirectory.appending(component: Bundle.main.bundleIdentifier ?? "Composition", directoryHint: .isDirectory)
        #expect(FileManager.default.url(for: .app) == folder)
    }

    @Test func urlForICloudDriveIsTheDocumentsFolderOfICloud() {
        #expect(FileManager.default.url(for: .iCloudDrive) == FileManager.default.url(for: .iCloud).appending(component: "Documents", directoryHint: .isDirectory))
    }

    #if os(macOS)
    @Test func urlForICloudIsOnTheDeviceWithoutAnAccount() {
        #expect(FileManager.default.url(for: .iCloud) == FileManager.default.localFolder(for: .iCloud))
    }
    #endif

    @Test func writeCreatesMissingFolders() throws {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/Nested/report.txt")
        try FileManager.default.write(Data("Dune".utf8), to: url)
        #expect(try Data(contentsOf: url) == Data("Dune".utf8))
    }

    @Test func writeOfNilIgnoresAMissingFile() throws {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try FileManager.default.write(nil, to: url)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func writeOfNilRemovesTheFile() throws {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data("Dune".utf8).write(to: url)
        try FileManager.default.write(nil, to: url)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func writeReplacesTheFile() throws {
        let url: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).txt")
        try Data("Dune".utf8).write(to: url)
        try FileManager.default.write(Data("Emma".utf8), to: url)
        #expect(try Data(contentsOf: url) == Data("Emma".utf8))
    }
}
#endif
