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
//   4. Run on a device or simulator signed in to iCloud. While iCloud is unavailable, url(for:) returns a folder on the device, and moveToICloud(_:at:) moves its files into iCloud once it's available.

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
    func coordinatedContents(of url: URL, presenter: (any NSFilePresenter)? = nil) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: presenter).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in result = Result { try Data(contentsOf: url) } }
        if let coordinationError: NSError { throw coordinationError }
        return try result.get()
    }

    /// Writes the data to the URL, or removes the file for `nil`, under file coordination so no other process or iCloud reads it midway.
    func coordinatedWrite(_ data: Data?, to url: URL, presenter: (any NSFilePresenter)? = nil) throws {
        var coordinationError: NSError?
        var result: Result<Void, any Error> = .success(())
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: data == nil ? .forDeleting : .forReplacing, error: &coordinationError) { url in result = Result { try write(data, to: url) } }
        if let coordinationError: NSError { throw coordinationError }
        try result.get()
    }

    /// Moves the file at the local URL into iCloud at the destination, returning `false` without moving it when there is no local file or iCloud already has one.
    @discardableResult
    func moveToICloud(_ local: URL, at destination: URL) throws -> Bool {
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

    /// Writes the data to the URL atomically, creating its folder, or removes the file for `nil` when there is one.
    func write(_ data: Data?, to url: URL) throws {
        guard let data: Data else {
            guard fileExists(atPath: url.path(percentEncoded: false)) else { return }
            return try removeItem(at: url)
        }
        try createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension FileManager {

    /// The app's bundle identifier, which names its folders.
    fileprivate static let bundleID: String = Bundle.main.bundleIdentifier ?? "Composition"

    /// The app's first iCloud container, or `nil` when iCloud isn't available.
    fileprivate static let iCloudContainer: URL? = FileManager.default.url(forUbiquityContainerIdentifier: nil)

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
}
#endif
