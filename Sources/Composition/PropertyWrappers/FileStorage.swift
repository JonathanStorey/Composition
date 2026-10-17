// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorage.swift
// dependencies: [Extensions/FileManager.swift, Protocols/FileRepresentable.swift]

// MARK: - Foundation + Observation + os + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(UniformTypeIdentifiers)
import Foundation
import Observation
import os
import UniformTypeIdentifiers

/// Reads and writes a value like `AppStorage`, kept in its own file inside the location in its own format when it is `FileRepresentable` and as JSON otherwise, cached in memory, written in the background, and, in the locations another process or iCloud can change, reloaded when the file changes on disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct FileStorage<Value: Codable & Sendable>: Sendable {

    private let defaultValue: Value
    private let file: FileManager.CachedFile
    private let isRepresentable: Bool

    /// Creates storage for the path that returns the default value until something is stored, where a path without an extension, such as "Settings/theme", gets the preferred extension of the `FileRepresentable` type's content type or ".json", stopping on a path that could leave the location, and stopping debug builds on a path without an extension when the content type has none.
    public init(wrappedValue: Value, _ path: String, _ location: Location = .app) {
        let violation: String? = FileManager.CachedFile.pathViolation(path)
        precondition(violation == nil, violation ?? "")
        let representable: (any FileRepresentable.Type)? = Value.self as? any FileRepresentable.Type
        let defaultExtension: String? = if let representable { representable.contentType.preferredFilenameExtension } else { "json" }
        if defaultExtension == nil, !FileManager.CachedFile.hasExtension(path) { assertionFailure("The FileStorage path \"\(path)\" needs an extension, since \(Value.self)'s content type has no preferred one.") }
        self.defaultValue = wrappedValue
        self.file = location.file(defaultExtension.map { FileManager.CachedFile.withExtension(path, $0) } ?? path)
        self.isRepresentable = representable != nil
    }

    /// Creates storage for the path that returns `nil` until something is stored.
    public init(_ path: String, _ location: Location = .app) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, path, location)
    }

    /// The value kept in the file, or the default value when there is none or it can't be read, where setting `nil` removes the file.
    public var wrappedValue: Value {
        get {
            guard let data: Data = file.contents else { return defaultValue }
            let value: Value? = if isRepresentable {
                DecodedValues.decode(data) { try (Value.self as? any FileRepresentable.Type)?.init(fileContents: $0) as? Value }
            } else {
                DecodedValues.decode(data) { try JSONDecoder().decode(Value.self, from: $0) }
            }
            return value ?? defaultValue
        }
        nonmutating set {
            let mirror: Mirror = Mirror(reflecting: newValue)
            guard mirror.displayStyle != .optional || !mirror.children.isEmpty else { return file.write(nil) }
            let contents: Data? = if isRepresentable { try? (newValue as? any FileRepresentable)?.fileContents() } else { try? JSONEncoder().encode(newValue) }
            file.write(contents)
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// The folder a file is kept in.
    typealias Location = FileManager.Location
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate extension FileManager.Location {

    /// The shared file at the path inside the location, watched for changes on disk only where another process or iCloud can make them, and in iCloud kept on the device until iCloud is available.
    func file(_ path: String) -> FileManager.CachedFile {
        let url: URL = FileManager.default.url(for: self).appending(path: path)
        switch self {
        case .app, .caches, .temp:
            return FileManager.default.cachedFile(at: url)
        case .documents, .group:
            return FileManager.default.cachedFile(at: url, watched: true)
        case .iCloud, .iCloudDrive:
            let local: URL = FileManager.default.localFolder(for: self).appending(path: path)
            guard url != local else { return FileManager.default.cachedFile(at: local) }
            return FileManager.default.cachedFile(at: url, watched: true, ubiquitous: true, moving: local)
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileManager {

    /// The cached file at the URL, shared by every caller and created on first use, whose folder is watched for changes on disk only when asked, since only another process or iCloud can change it behind the app's back.
    func cachedFile(at url: URL, watched: Bool = false, ubiquitous: Bool = false, moving local: URL? = nil) -> CachedFile {
        CachedFile.files.withLock { files in
            if let file: CachedFile = files[url] { return file }
            let file: CachedFile = CachedFile(url, watched: watched, ubiquitous: ubiquitous, moving: local)
            files[url] = file
            return file
        }
    }

    /// One file's contents, shared by every wrapper for the same file, kept in memory after the first read, written in the background, and, when watched, reloaded when the file changes on disk.
    final class CachedFile: NSObject, NSFilePresenter, Observable, Sendable {

        private let isUbiquitous: Bool
        private let isWriting: OSAllocatedUnfairLock<Bool> = OSAllocatedUnfairLock(initialState: false)
        private let queue: DispatchQueue = DispatchQueue(label: "Composition.FileStorage", qos: .utility)
        private let registrar: ObservationRegistrar = ObservationRegistrar()
        private let state: OSAllocatedUnfairLock<Contents> = OSAllocatedUnfairLock(initialState: Contents())
        private let url: URL
        private let watcher: OSAllocatedUnfairLock<(any DispatchSourceFileSystemObject)?> = OSAllocatedUnfairLock(uncheckedState: nil)

        /// Creates the file at the URL, watching its folder when asked and, in iCloud Drive, presenting it, and moving in the local copy kept while iCloud was unavailable.
        fileprivate init(_ url: URL, watched: Bool, ubiquitous: Bool, moving local: URL?) {
            self.isUbiquitous = ubiquitous
            self.url = url
            super.init()
            if watched { watch() }
            if ubiquitous { NSFileCoordinator.addFilePresenter(self) }
            if let local: URL { queue.async { [self] in move(local) } }
        }

        /// Every file in use, by URL.
        fileprivate static let files: OSAllocatedUnfairLock<[URL: CachedFile]> = OSAllocatedUnfairLock(initialState: [:])

        /// Waits for every write still waiting to reach the disk, in every file in use.
        public static func flush() {
            files.withLock { Array($0.values) }.forEach { $0.queue.sync {} }
        }

        /// A Boolean value indicating whether the path's last name has an extension.
        public static func hasExtension(_ path: String) -> Bool {
            path.split(separator: "/").last?.contains(".") == true
        }

        /// Why the path can't name a file inside its location, or `nil` when it can: a relative path of names, none empty or starting with ".".
        public static func pathViolation(_ path: String) -> String? {
            guard !path.hasPrefix("/"), path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") }) else { return "The FileStorage path \"\(path)\" must be relative, without empty components or ones starting with \".\"." }
            return nil
        }

        /// The path as given when its last name has an extension, or with the default extension added when it has none.
        public static func withExtension(_ path: String, _ defaultExtension: String) -> String {
            hasExtension(path) ? path : "\(path).\(defaultExtension)"
        }

        /// The file's contents, read once from disk and from memory after that, or `nil` when there is no file.
        public var contents: Data? {
            registrar.access(self, keyPath: \.revision)
            return state.withLock { contents in
                if !contents.isLoaded { contents = Contents(data: read(), isLoaded: true) }
                return contents.data
            }
        }

        /// The queue that tells the file of changes made by other processes and by iCloud.
        public var presentedItemOperationQueue: OperationQueue {
            .main
        }

        /// The URL of the file, for iCloud Drive's coordination.
        public var presentedItemURL: URL? {
            url
        }

        /// A placeholder property that observers track in place of the contents.
        private var revision: Void { () }

        /// Reloads the file after another process or iCloud changed it.
        public func presentedItemDidChange() {
            queue.async { [self] in reload() }
        }

        /// Keeps the contents in memory and tells observers at once, then writes them to disk in the background, where newer contents replace any still waiting, and `nil` removes the file.
        public func write(_ data: Data?) {
            registrar.withMutation(of: self, keyPath: \.revision) {
                state.withLock { $0 = Contents(data: data, isLoaded: true, writes: $0.writes + 1) }
            }
            let isIdle: Bool = isWriting.withLock { isWriting in
                defer { isWriting = true }
                return !isWriting
            }
            guard isIdle else { return }
            queue.async { [self] in
                isWriting.withLock { $0 = false }
                save(state.withLock { $0.data })
            }
        }

        /// Moves the copy kept on the device while iCloud was unavailable into iCloud, unless iCloud already has the file.
        private func move(_ local: URL) {
            guard (try? FileManager.default.moveItemToICloud(at: local, to: url)) == true else { return }
            reload()
        }

        /// The file's contents on disk, read through iCloud Drive's coordination when it lives there, starting a download when only iCloud has it.
        private func read() -> Data? {
            guard isUbiquitous else { return try? Data(contentsOf: url) }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return try? FileManager.default.contents(at: url, presenter: self)
        }

        /// Takes in the file as it is on disk, keeping iCloud's chosen version of a conflict, unless this process wrote since the reload began or a write is still waiting.
        private func reload() {
            let writes: Int = state.withLock { $0.writes }
            guard !isWriting.withLock({ $0 }) else { return }
            #if os(iOS) || os(macOS) || os(visionOS)
            if isUbiquitous, let conflicts: [NSFileVersion] = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty {
                conflicts.forEach { $0.isResolved = true }
                try? NSFileVersion.removeOtherVersionsOfItem(at: url)
            }
            #endif
            let data: Data? = read()
            guard data != state.withLock({ $0.data }) else { return }
            registrar.withMutation(of: self, keyPath: \.revision) {
                state.withLock { contents in
                    guard contents.writes == writes else { return }
                    contents.data = data
                    contents.isLoaded = true
                }
            }
        }

        /// Writes the contents atomically under file coordination, or removes the file for `nil`.
        private func save(_ data: Data?) {
            try? FileManager.default.write(data, to: url, presenter: self)
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
}

/// A file's contents in memory, whether they were read from disk yet, and how many writes this process made.
fileprivate struct Contents: Sendable {

    var data: Data?
    var isLoaded: Bool = false
    var writes: Int = 0
}

/// Values decoded from stored files, remembered by the data they came from so reading unchanged data again skips the decoder, and dropped when memory runs low.
fileprivate enum DecodedValues {

    /// The decoded values, keyed by the data they came from.
    nonisolated(unsafe) private static let cache: NSCache<NSData, DecodedValue> = NSCache()

    /// The value the decoder makes from the data, taken from the cache when the same data was decoded as the same type before.
    static func decode<V>(_ data: Data, with decoder: (Data) throws -> V?) -> V? {
        if let decoded: DecodedValue = cache.object(forKey: data as NSData), let value: V = decoded.value as? V { return value }
        guard let value: V = try? decoder(data) else { return nil }
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

// MARK: - Foundation + Observation + os + SwiftUI + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// A binding to the value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
