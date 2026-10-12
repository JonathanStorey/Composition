// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorage.swift
// dependencies: []
// permissions: [com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, com.apple.developer.ubiquity-container-identifiers, LSSupportsOpeningDocumentsInPlace, NSUbiquitousContainers, UIFileSharingEnabled]

// Setup in Xcode:
// - .app and .temp need nothing.
// - .documents needs nothing to work. To let people see the files in the Files app on iOS, open the target's Info tab and set both UIFileSharingEnabled (Application supports iTunes file sharing) and LSSupportsOpeningDocumentsInPlace (Supports opening documents in place) to YES.
// - .iCloud:
//   1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
//   2. Under iCloud, check iCloud Documents and select or create the container named iCloud. followed by the bundle identifier. FileStorage uses the first container listed.
//   3. To show the files in iCloud Drive, add NSUbiquitousContainers to the Info tab: a dictionary keyed by the container identifier, holding NSUbiquitousContainerIsDocumentScopePublic set to YES, NSUbiquitousContainerName set to the folder's name, and NSUbiquitousContainerSupportedFolderLevels set to Any. Raise the build number so iCloud Drive notices the change.
//   4. Run on a device or simulator signed in to iCloud. While iCloud is unavailable the file stays on the device and moves to iCloud Drive at the first launch that can reach it.

// MARK: - Foundation + Observation + os

#if canImport(Foundation) && canImport(Observation) && canImport(os)
import Foundation
import Observation
import os

/// Reads and writes a value like `AppStorage`, kept in its own file at a path inside the location, cached in memory, written in the background, and reloaded when another process or iCloud changes the file.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct FileStorage<Value: Codable & Sendable>: Sendable {

    private let defaultValue: Value
    private let file: StoredFile

    /// Creates storage for the relative path, such as "Settings/theme.json", that returns the default value until something is stored, stopping on a path that could leave the location or doesn't name a file.
    public init(wrappedValue: Value, _ path: String, _ location: Location = .app) {
        precondition(StoredFile.pathViolation(path) == nil, StoredFile.pathViolation(path) ?? "")
        self.defaultValue = wrappedValue
        self.file = location.file(path)
    }

    /// Creates storage for the relative path that returns `nil` until something is stored.
    public init(_ path: String, _ location: Location = .app) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, path, location)
    }

    /// The value kept in the file, or the default value when there is none or it can't be decoded, where `Data` is kept as is, anything else as JSON, and setting `nil` removes the file.
    public var wrappedValue: Value {
        get {
            guard let data: Data = file.data else { return defaultValue }
            if let raw: Value = data as? Value { return raw }
            return DecodedValues.decode(Value.self, from: data) ?? defaultValue
        }
        nonmutating set {
            if let data: Data = newValue as? Data { return file.write(data) }
            file.write((try? JSONEncoder().encode(newValue)).flatMap { $0 == Data("null".utf8) ? nil : $0 })
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// The folder a file is kept in.
    enum Location: Hashable, Sendable {

        /// The app's own folder in Application Support, backed up and hidden from the user.
        case app

        /// The app's Documents folder, backed up and visible in the Files app when the app shares its files.
        case documents

        /// The temporary folder, which isn't backed up and which the system may empty when the app isn't running.
        case temp

        /// The app's iCloud Drive container, synced across the user's devices, or a folder on the device until iCloud is available.
        case iCloud

        /// The stored file for the path inside the location.
        fileprivate func file(_ path: String) -> StoredFile {
            switch self {
            case .app: StoredFile.at(StoredFile.appFolder.appending(path: path))
            case .documents: StoredFile.at(URL.documentsDirectory.appending(path: path))
            case .temp: StoredFile.at(URL.temporaryDirectory.appending(path: path))
            case .iCloud: StoredFile.iCloudFolder.map { StoredFile.at($0.appending(path: path), ubiquitous: true, moving: StoredFile.localICloudFolder.appending(path: path)) } ?? StoredFile.at(StoredFile.localICloudFolder.appending(path: path))
            }
        }
    }
}

/// One file's contents, shared by every wrapper for the same file, kept in memory after the first read, written in the background, and reloaded when the file changes on disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class StoredFile: NSObject, NSFilePresenter, Observable, Sendable {

    private let contents: OSAllocatedUnfairLock<Contents> = OSAllocatedUnfairLock(initialState: Contents())
    private let isUbiquitous: Bool
    private let isWriting: OSAllocatedUnfairLock<Bool> = OSAllocatedUnfairLock(initialState: false)
    private let queue: DispatchQueue = DispatchQueue(label: "Composition.FileStorage", qos: .utility)
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let url: URL
    private let watcher: OSAllocatedUnfairLock<(any DispatchSourceFileSystemObject)?> = OSAllocatedUnfairLock(uncheckedState: nil)

    /// Creates the file at the URL, watching its folder and, in iCloud Drive, presenting it, and moving in the local copy kept while iCloud was unavailable.
    private init(_ url: URL, ubiquitous: Bool, moving local: URL?) {
        self.isUbiquitous = ubiquitous
        self.url = url
        super.init()
        watch()
        if ubiquitous { NSFileCoordinator.addFilePresenter(self) }
        if let local: URL { queue.async { [self] in move(local) } }
    }

    /// The app's own folder in Application Support, kept apart for each app on macOS, where apps share Application Support.
    fileprivate static let appFolder: URL = URL.applicationSupportDirectory.appending(component: Bundle.main.bundleIdentifier ?? "Composition", directoryHint: .isDirectory)

    /// The Documents folder of the app's first iCloud container, or `nil` when iCloud isn't available.
    fileprivate static let iCloudFolder: URL? = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(component: "Documents", directoryHint: .isDirectory)

    /// The folder on the device that keeps iCloud files until iCloud is available, beside the app's own folder so no path inside it can collide.
    fileprivate static let localICloudFolder: URL = URL.applicationSupportDirectory.appending(component: "\(Bundle.main.bundleIdentifier ?? "Composition").iCloud", directoryHint: .isDirectory)

    /// Every file in use, by URL.
    private static let files: OSAllocatedUnfairLock<[URL: StoredFile]> = OSAllocatedUnfairLock(initialState: [:])

    /// Waits for every write still waiting to reach the disk, in every file in use.
    static func flushAll() {
        files.withLock { Array($0.values) }.forEach { $0.queue.sync {} }
    }

    /// Why the path can't name a file inside its location, or `nil` when it can: a relative path whose components are all names.
    static func pathViolation(_ path: String) -> String? {
        let components: [Substring] = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return "The FileStorage path \"\(path)\" must be relative, such as \"Settings/theme.json\", without empty, \".\" or \"..\" components." }
        return nil
    }

    /// The shared file at the URL, created on first use.
    fileprivate static func at(_ url: URL, ubiquitous: Bool = false, moving local: URL? = nil) -> StoredFile {
        files.withLock { files in
            if let file: StoredFile = files[url] { return file }
            let file: StoredFile = StoredFile(url, ubiquitous: ubiquitous, moving: local)
            files[url] = file
            return file
        }
    }

    /// The file's contents, read once from disk and from memory after that, or `nil` when there is no file.
    var data: Data? {
        registrar.access(self, keyPath: \.revision)
        return contents.withLock { contents in
            if !contents.isLoaded { contents = Contents(data: read(), isLoaded: true) }
            return contents.data
        }
    }

    /// The queue that tells the file of changes made by other processes and by iCloud.
    var presentedItemOperationQueue: OperationQueue {
        .main
    }

    /// The URL of the file, for iCloud Drive's coordination.
    var presentedItemURL: URL? {
        url
    }

    /// A placeholder property that observers track in place of the contents.
    private var revision: Void { () }

    /// Reloads the file after another process or iCloud changed it.
    func presentedItemDidChange() {
        queue.async { [self] in reload() }
    }

    /// Keeps the contents in memory and tells observers at once, then writes them to disk in the background, where newer contents replace any still waiting, and `nil` removes the file.
    func write(_ data: Data?) {
        registrar.withMutation(of: self, keyPath: \.revision) {
            contents.withLock { $0 = Contents(data: data, isLoaded: true, writes: $0.writes + 1) }
        }
        let isIdle: Bool = isWriting.withLock { isWriting in
            defer { isWriting = true }
            return !isWriting
        }
        guard isIdle else { return }
        queue.async { [self] in
            isWriting.withLock { $0 = false }
            save(contents.withLock { $0.data })
        }
    }

    /// Moves the copy kept on the device while iCloud was unavailable into iCloud Drive, unless iCloud already has the file.
    private func move(_ local: URL) {
        let manager: FileManager = FileManager.default
        guard manager.fileExists(atPath: local.path(percentEncoded: false)), !manager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.setUbiquitous(true, itemAt: local, destinationURL: url)
        reload()
    }

    /// The file's contents on disk, read through iCloud Drive's coordination when it lives there, starting a download when only iCloud has it.
    private func read() -> Data? {
        guard isUbiquitous else { return try? Data(contentsOf: url) }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        var data: Data?
        NSFileCoordinator(filePresenter: self).coordinate(readingItemAt: url, options: [], error: nil) { url in data = try? Data(contentsOf: url) }
        return data
    }

    /// Takes in the file as it is on disk, keeping iCloud's chosen version of a conflict, unless this process wrote since the reload began or a write is still waiting.
    private func reload() {
        let writes: Int = contents.withLock { $0.writes }
        guard !isWriting.withLock({ $0 }) else { return }
        #if os(iOS) || os(macOS) || os(visionOS)
        if isUbiquitous, let conflicts: [NSFileVersion] = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty {
            conflicts.forEach { $0.isResolved = true }
            try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        }
        #endif
        let data: Data? = read()
        guard data != contents.withLock({ $0.data }) else { return }
        registrar.withMutation(of: self, keyPath: \.revision) {
            contents.withLock { contents in
                guard contents.writes == writes else { return }
                contents.data = data
                contents.isLoaded = true
            }
        }
    }

    /// Writes the contents atomically, or removes the file for `nil`, through iCloud Drive's coordination when it lives there.
    private func save(_ data: Data?) {
        let replace: (URL) -> Void = { url in
            guard let data: Data else { try? FileManager.default.removeItem(at: url); return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        guard isUbiquitous else { return replace(url) }
        NSFileCoordinator(filePresenter: self).coordinate(writingItemAt: url, options: data == nil ? .forDeleting : .forReplacing, error: nil, byAccessor: replace)
    }

    /// Watches the file's folder, which sees a file replaced by an atomic write where watching the file itself would not, and reloads on every change.
    private func watch() {
        let folder: URL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor: Int32 = open(folder.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source: any DispatchSourceFileSystemObject = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler { [weak self] in self?.reload() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher.withLockUnchecked { $0 = source }
    }
}

/// A file's contents in memory, whether they were read from disk yet, and how many writes this process made.
fileprivate struct Contents: Sendable {

    var data: Data?
    var isLoaded: Bool = false
    var writes: Int = 0
}

/// Values decoded from stored JSON, remembered by the data they came from so reading unchanged data again skips the decoder, and dropped when memory runs low.
fileprivate enum DecodedValues {

    /// The decoded values, keyed by the data they came from.
    nonisolated(unsafe) private static let cache: NSCache<NSData, DecodedValue> = NSCache()

    /// The value the data decodes to, taken from the cache when the same data was decoded as the same type before.
    static func decode<V: Decodable>(_ type: V.Type, from data: Data) -> V? {
        if let decoded: DecodedValue = cache.object(forKey: data as NSData), let value: V = decoded.value as? V { return value }
        guard let value: V = try? JSONDecoder().decode(V.self, from: data) else { return nil }
        cache.setObject(DecodedValue(value), forKey: data as NSData)
        return value
    }
}

/// A decoded value, boxed so `NSCache` can hold it.
fileprivate final class DecodedValue {

    let value: Any

    /// Boxes the value.
    init(_ value: Any) {
        self.value = value
    }
}
#endif

// MARK: - Foundation + Observation + os + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// A binding to the value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
