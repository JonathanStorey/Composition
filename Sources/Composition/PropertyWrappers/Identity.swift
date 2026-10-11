// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Identity.swift
// dependencies: [Extensions/Date.swift, Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/EncryptedStorage.swift, PropertyWrappers/SyncedStorage.swift]

// MARK: - Foundation + Observation + Security

#if canImport(Foundation) && canImport(Observation) && canImport(Security)
import Foundation
import Security

/// The identities for scopes that outlive views and scenes, each created on first read.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
enum Identities {

    /// Kept in this device's Keychain, or the install's when the Keychain refuses it.
    static let device: UUID = identity(in: .localOnly, or: install)

    /// Kept in Application Support and excluded from backup.
    static let install: UUID = identity(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "Identity"))

    /// Created when the app launches and gone when it quits.
    static let launch: UUID = .timestamp

    /// Reads the identity stored at the URL, or stores a new one there, excluded from backup, when none can be read.
    static func identity(at url: URL) -> UUID {
        if let contents: String = try? String(contentsOf: url, encoding: .utf8), let identity: UUID = UUID(uuidString: contents.trimmed), identity.version == 7 { return identity }
        let identity: UUID = .timestamp
        var location: URL = url
        var values: URLResourceValues = URLResourceValues()
        values.isExcludedFromBackup = true
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? identity.uuidString.write(to: url, atomically: true, encoding: .utf8)
        try? location.setResourceValues(values)
        return identity
    }

    /// Reads the identity stored in the Keychain at the location, or stores a new one there, returning the fallback when the Keychain refuses it.
    private static func identity(in location: EncryptedStorage<UUID?>.Location, or fallback: @autoclosure () -> UUID) -> UUID {
        let storage: EncryptedStorage<UUID?> = EncryptedStorage("\(location)", location, service: "Composition.Identity")
        if let identity: UUID = storage.wrappedValue, identity.version == 7 { return identity }
        storage.wrappedValue = .timestamp
        return storage.wrappedValue ?? fallback()
    }
}
#endif

// MARK: - Foundation + Observation + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

/// A version 7 UUID created on first read and shared by every wrapper of its scope, from a single view to the whole device.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct Identity: DynamicProperty {

    /// How widely an identity is shared and how long it lasts, from shortest to longest.
    public enum Scope: Hashable, Sendable {

        /// Stays the same while the view keeps its identity, and is new for every view.
        case view

        /// Stays the same for the scene, survives state restoration, and is shared by every view in the scene.
        case scene

        /// Stays the same until the app quits.
        case launch

        /// Stays the same until the app is deleted, and is never backed up or restored onto another device.
        case install

        /// Stays the same across reinstalls, and is never restored onto another device.
        case device
    }

    /// How widely the identity is shared and how long it lasts.
    public let scope: Scope
    @SceneStorage("Composition.Identity.scene") private var sceneIdentity: String?
    @State private var viewIdentity: UUID = .timestamp

    /// Creates an identity shared within the scope.
    public init(of scope: Scope) {
        self.scope = scope
    }

    /// The last time the identity synced, which is when it was created for scopes that never sync.
    public var lastSynced: Date? {
        Date(timestamp: wrappedValue)
    }

    /// The wrapper itself, for its sync status and refresh.
    public var projectedValue: Identity {
        self
    }

    /// The status of the identity's last sync, which is always a success at its creation for scopes that never sync.
    public var status: SyncStatus {
        .success(Date(timestamp: wrappedValue) ?? .distantPast)
    }

    /// The identity, created on first read and reused for as long as the scope lives.
    public var wrappedValue: UUID {
        switch scope {
        case .device: Identities.device
        case .install: Identities.install
        case .launch: Identities.launch
        case .scene: storedSceneIdentity()
        case .view: viewIdentity
        }
    }

    /// Brings the identity up to date: a new identity for a view or scene, and nothing for scopes fixed for their lifetime.
    public func refresh() {
        switch scope {
        case .device, .install, .launch: break
        case .scene: sceneIdentity = UUID.timestamp.uuidString
        case .view: viewIdentity = .timestamp
        }
    }

    /// Reads the scene's identity, storing this view's identity as the scene's when the scene has none yet.
    private func storedSceneIdentity() -> UUID {
        if let identity: UUID = sceneIdentity.flatMap(UUID.init(uuidString:)), identity.version == 7 { return identity }
        sceneIdentity = viewIdentity.uuidString
        return viewIdentity
    }
}
#endif
