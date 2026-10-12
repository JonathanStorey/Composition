// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorage.swift
// dependencies: []
// permissions: [com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, com.apple.developer.ubiquity-container-identifiers, com.apple.security.application-groups, LSSupportsOpeningDocumentsInPlace, NSUbiquitousContainers, UIFileSharingEnabled]

// Setup in Xcode:
// - .app, .caches and .temp need nothing.
// - .documents, for Data only, needs nothing to work. To let people see the files in the Files app on iOS, open the target's Info tab and set both UIFileSharingEnabled (Application supports iTunes file sharing) and LSSupportsOpeningDocumentsInPlace (Supports opening documents in place) to YES.
// - .group("group.com.example"): select the app target and each extension that shares the file, open Signing & Capabilities, click + Capability, add App Groups, and check the same group identifier in every target.
// - .iCloud and .iCloudDrive:
//   1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
//   2. Under iCloud, check iCloud Documents and select or create the container named iCloud. followed by the bundle identifier. FileStorage uses the first container listed.
//   3. .iCloud keeps files hidden in the container. For .iCloudDrive, which is for Data only, show the files in iCloud Drive by adding NSUbiquitousContainers to the Info tab: a dictionary keyed by the container identifier, holding NSUbiquitousContainerIsDocumentScopePublic set to YES, NSUbiquitousContainerName set to the folder's name, and NSUbiquitousContainerSupportedFolderLevels set to Any. Raise the build number so iCloud Drive notices the change.
//   4. Run on a device or simulator signed in to iCloud. While iCloud is unavailable the file stays on the device and moves to iCloud at the first launch that can reach it.

// MARK: - Foundation + Observation + os

#if canImport(Foundation) && canImport(Observation) && canImport(os)
import Foundation
import Observation
import os

/// Reads and writes a value like `AppStorage`, kept in its own file inside the location as JSON or, for `Data`, exactly as given, cached in memory, written in the background, and reloaded when another process or iCloud changes the file.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct FileStorage<Value: Codable & Sendable>: Sendable {

    private let defaultValue: Value
    private let file: StoredFile
    private let isRaw: Bool

    /// Creates storage for the path that returns the default value until something is stored, where `Data` keeps its path and extension, as in "Images/avatar.png", and any other value is kept as JSON with ".json" added to a name without one, as in "Settings/theme", stopping on a path that could leave the location or misuses an extension.
    public init(wrappedValue: Value, _ path: String, _ location: Location = .app) {
        let isRaw: Bool = Value.self == Data.self || Value.self == Data?.self
        let violation: String? = StoredFile.pathViolation(path, isFile: isRaw)
        precondition(violation == nil, violation ?? "")
        self.defaultValue = wrappedValue
        self.file = location.folder.file(isRaw ? path : "\(path).json")
        self.isRaw = isRaw
    }

    /// Creates storage for the path that returns `nil` until something is stored.
    public init(_ path: String, _ location: Location = .app) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, path, location)
    }

    /// The value kept in the file, or the default value when there is none or it can't be decoded, where `Data` is kept exactly as given, anything else as JSON, and setting `nil` removes the file.
    public var wrappedValue: Value {
        get {
            guard let data: Data = file.data else { return defaultValue }
            if isRaw, let raw: Value = data as? Value { return raw }
            return DecodedValues.decode(Value.self, from: data) ?? defaultValue
        }
        nonmutating set {
            if isRaw, let data: Data = newValue as? Data { return file.write(data) }
            file.write((try? JSONEncoder().encode(newValue)).flatMap { $0 == Data("null".utf8) ? nil : $0 })
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// The folder a file is kept in, where every value can use the hidden ones and only `Data` can use `.documents` and `.iCloudDrive`, which people can see.
    struct Location: Hashable, Sendable {

        fileprivate let folder: Folder

        /// The app's own folder in Application Support, backed up and hidden from the user.
        public static var app: Self {
            Self(folder: .app)
        }

        /// The app's caches folder, which isn't backed up and which the system may empty when space runs low.
        public static var caches: Self {
            Self(folder: .caches)
        }

        /// The app's iCloud container, synced across the user's devices and hidden from iCloud Drive, or a folder on the device until iCloud is available.
        public static var iCloud: Self {
            Self(folder: .iCloud(visible: false))
        }

        /// The temporary folder, which isn't backed up and which the system may empty when the app isn't running.
        public static var temp: Self {
            Self(folder: .temp)
        }

        /// The shared container of the app group with the identifier, which the app and its extensions can all read and write.
        public static func group(_ identifier: String) -> Self {
            Self(folder: .group(identifier))
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage.Location where Value == Data {

    /// The app's Documents folder, backed up and visible in the Files app when the app shares its files.
    static var documents: Self {
        Self(folder: .documents)
    }

    /// The Documents folder of the app's iCloud container, synced across the user's devices and visible in iCloud Drive when the app makes it public, or a folder on the device until iCloud is available.
    static var iCloudDrive: Self {
        Self(folder: .iCloud(visible: true))
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage.Location where Value == Data? {

    /// The app's Documents folder, backed up and visible in the Files app when the app shares its files.
    static var documents: Self {
        Self(folder: .documents)
    }

    /// The Documents folder of the app's iCloud container, synced across the user's devices and visible in iCloud Drive when the app makes it public, or a folder on the device until iCloud is available.
    static var iCloudDrive: Self {
        Self(folder: .iCloud(visible: true))
    }
}

/// A folder a file can be kept in, whatever it holds.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate enum Folder: Hashable {

    case app, caches, documents, group(String), iCloud(visible: Bool), temp

    /// The shared file at the path inside the folder, where an app group the app can't reach stops debug builds and falls back to the app's own folder, and iCloud falls back to the device until it's available.
    func file(_ path: String) -> StoredFile {
        switch self {
        case .app:
            return StoredFile.at(StoredFile.appFolder.appending(path: path))
        case .caches:
            return StoredFile.at(URL.cachesDirectory.appending(component: StoredFile.bundleID, directoryHint: .isDirectory).appending(path: path))
        case .documents:
            return StoredFile.at(URL.documentsDirectory.appending(path: path))
        case .group(let identifier):
            guard let container: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                assertionFailure("The app can't reach the app group \"\(identifier)\". Add it under Signing & Capabilities > App Groups.")
                return StoredFile.at(StoredFile.appFolder.appending(component: identifier, directoryHint: .isDirectory).appending(path: path))
            }
            return StoredFile.at(container.appending(path: path))
        case .iCloud(let visible):
            let local: URL = (visible ? StoredFile.localICloudFolder.appending(component: "Documents", directoryHint: .isDirectory) : StoredFile.localICloudFolder).appending(path: path)
            guard let container: URL = StoredFile.iCloudContainer else { return StoredFile.at(local) }
            return StoredFile.at((visible ? container.appending(component: "Documents", directoryHint: .isDirectory) : container).appending(path: path), ubiquitous: true, moving: local)
        case .temp:
            return StoredFile.at(URL.temporaryDirectory.appending(path: path))
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
    fileprivate static let appFolder: URL = URL.applicationSupportDirectory.appending(component: bundleID, directoryHint: .isDirectory)

    /// The app's bundle identifier, which names its folders.
    fileprivate static let bundleID: String = Bundle.main.bundleIdentifier ?? "Composition"

    /// The app's first iCloud container, or `nil` when iCloud isn't available.
    fileprivate static let iCloudContainer: URL? = FileManager.default.url(forUbiquityContainerIdentifier: nil)

    /// The folder on the device that keeps iCloud files until iCloud is available, beside the app's own folder so no path inside it can collide.
    fileprivate static let localICloudFolder: URL = URL.applicationSupportDirectory.appending(component: "\(bundleID).iCloud", directoryHint: .isDirectory)

    /// Every file in use, by URL.
    private static let files: OSAllocatedUnfairLock<[URL: StoredFile]> = OSAllocatedUnfairLock(initialState: [:])

    /// Waits for every write still waiting to reach the disk, in every file in use.
    static func flushAll() {
        files.withLock { Array($0.values) }.forEach { $0.queue.sync {} }
    }

    /// Why the path can't name a file inside its location, or `nil` when it can: a relative path of names, none starting with ".", whose last name has an extension for a file and none for a name that gets ".json".
    static func pathViolation(_ path: String, isFile: Bool) -> String? {
        let components: [Substring] = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), components.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") }) else { return "The FileStorage path \"\(path)\" must be relative, without empty components or ones starting with \".\"." }
        let hasExtension: Bool = components.last?.contains(".") ?? false
        if isFile, !hasExtension { return "The FileStorage path \"\(path)\" for data needs a file name with an extension, such as \"Images/avatar.png\"." }
        if !isFile, hasExtension { return "The FileStorage name \"\(path)\" can't have an extension, since FileStorage adds \".json\", as in \"Settings/theme\"." }
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
