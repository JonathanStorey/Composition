// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/FileManager.swift
// dependencies: []
// permissions: [com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, com.apple.developer.ubiquity-container-identifiers, com.apple.security.application-groups, LSSupportsOpeningDocumentsInPlace, NSUbiquitousContainers, UIFileSharingEnabled]

// Setup in Xcode:
// - .app, .caches and .temp need nothing.
// - .documents needs nothing to work. To let people see the files in the Files app on iOS, open the target's Info tab and set both UIFileSharingEnabled (Application supports iTunes file sharing) and LSSupportsOpeningDocumentsInPlace (Supports opening documents in place) to YES.
// - .group("group.com.example"): select the app target and each extension that shares the folder, open Signing & Capabilities, click + Capability, add App Groups, and check the same group identifier in every target.
// - .iCloud and .iCloudDrive:
//   1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
//   2. Under iCloud, check iCloud Documents and select or create the container named iCloud. followed by the bundle identifier. url(for:) uses the first container listed.
//   3. .iCloud keeps files hidden in the container. For .iCloudDrive, show the files in iCloud Drive by adding NSUbiquitousContainers to the Info tab: a dictionary keyed by the container identifier, holding NSUbiquitousContainerIsDocumentScopePublic set to YES, NSUbiquitousContainerName set to the folder's name, and NSUbiquitousContainerSupportedFolderLevels set to Any. Raise the build number so iCloud Drive notices the change.
//   4. Run on a device or simulator signed in to iCloud. While iCloud is unavailable, url(for:) returns a folder on the device, and moveItemToICloud(at:to:) moves its files into iCloud once it's available.

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileManager {

    /// A folder for the app's files, from its own hidden folder to iCloud Drive.
    enum Location: Hashable, Sendable {

        /// The app's own folder in Application Support, backed up, hidden from the user, and changed only by the app.
        case app

        /// The app's caches folder, which isn't backed up, which the system may empty when space runs low, and which only the app changes.
        case caches

        /// The app's Documents folder, backed up and visible in the Files app when the app shares its files.
        case documents

        /// The shared container of the app group with the identifier, which the app and its extensions can all read and write.
        case group(String)

        /// The app's iCloud container, synced across the user's devices and hidden from iCloud Drive, or a folder on the device until iCloud is available.
        case iCloud

        /// The Documents folder of the app's iCloud container, synced across the user's devices and visible in iCloud Drive when the app makes it public, or a folder on the device until iCloud is available.
        case iCloudDrive

        /// The temporary folder, which isn't backed up, which the system may empty when the app isn't running, and which only the app changes.
        case temp
    }

    /// The contents of the file at the URL, read under file coordination so no other process or iCloud changes it midway.
    func contents(at url: URL, presenter: (any NSFilePresenter)? = nil) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: presenter).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in result = Result { try Data(contentsOf: url) } }
        if let coordinationError: NSError { throw coordinationError }
        return try result.get()
    }

    /// The folder on the device that keeps the location's files until iCloud is available, beside the app's own folder so no path inside it can collide, or the location's own folder when it isn't in iCloud.
    func localFolder(for location: Location) -> URL {
        let iCloud: URL = URL.applicationSupportDirectory.appending(component: "\(Self.bundleID).iCloud", directoryHint: .isDirectory)
        switch location {
        case .iCloud:
            return iCloud
        case .iCloudDrive:
            return iCloud.appending(component: "Documents", directoryHint: .isDirectory)
        case .app, .caches, .documents, .group, .temp:
            return url(for: location)
        }
    }

    /// Moves the file at the local URL into iCloud at the destination, returning `false` without moving it when there is no local file or iCloud already has one.
    @discardableResult
    func moveItemToICloud(at local: URL, to destination: URL) throws -> Bool {
        guard fileExists(atPath: local.path(percentEncoded: false)), !fileExists(atPath: destination.path(percentEncoded: false)) else { return false }
        try createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try setUbiquitous(true, itemAt: local, destinationURL: destination)
        return true
    }

    /// The location's folder, which for iCloud is a folder on the device until iCloud is available, and for an app group the app can't reach stops debug builds and falls back to a folder inside the app's own folder.
    func url(for location: Location) -> URL {
        switch location {
        case .app:
            return URL.applicationSupportDirectory.appending(component: Self.bundleID, directoryHint: .isDirectory)
        case .caches:
            return URL.cachesDirectory.appending(component: Self.bundleID, directoryHint: .isDirectory)
        case .documents:
            return URL.documentsDirectory
        case .group(let identifier):
            guard let container: URL = containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                assertionFailure("The app can't reach the app group \"\(identifier)\". Add it under Signing & Capabilities > App Groups.")
                return url(for: .app).appending(component: identifier, directoryHint: .isDirectory)
            }
            return container
        case .iCloud:
            return Self.iCloudContainer ?? localFolder(for: .iCloud)
        case .iCloudDrive:
            return Self.iCloudContainer?.appending(component: "Documents", directoryHint: .isDirectory) ?? localFolder(for: .iCloudDrive)
        case .temp:
            return URL.temporaryDirectory
        }
    }

    /// Writes the data to the URL atomically under file coordination, creating its folder, or removes the file for `nil` when there is one.
    func write(_ data: Data?, to url: URL, presenter: (any NSFilePresenter)? = nil) throws {
        var coordinationError: NSError?
        var result: Result<Void, any Error> = .success(())
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: data == nil ? .forDeleting : .forReplacing, error: &coordinationError) { url in
            result = Result {
                guard let data: Data else {
                    guard fileExists(atPath: url.path(percentEncoded: false)) else { return }
                    return try removeItem(at: url)
                }
                try createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            }
        }
        if let coordinationError: NSError { throw coordinationError }
        try result.get()
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension FileManager {

    /// The app's bundle identifier, which names its folders.
    fileprivate static let bundleID: String = Bundle.main.bundleIdentifier ?? "Composition"

    /// The app's first iCloud container, or `nil` when iCloud isn't available.
    fileprivate static let iCloudContainer: URL? = FileManager.default.url(forUbiquityContainerIdentifier: nil)
}
#endif

// MARK: - Foundation + Observation + os

#if canImport(Foundation) && canImport(Observation) && canImport(os)
import Observation
import os

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

    /// One file's contents, shared by every caller for the same file, kept in memory after the first read, written in the background, and, when watched, reloaded when the file changes on disk.
    final class CachedFile: NSObject, NSFilePresenter, Observable, Sendable {

        private let isUbiquitous: Bool
        private let isWriting: OSAllocatedUnfairLock<Bool> = OSAllocatedUnfairLock(initialState: false)
        private let queue: DispatchQueue = DispatchQueue(label: "Composition.CachedFile", qos: .utility)
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
#endif
