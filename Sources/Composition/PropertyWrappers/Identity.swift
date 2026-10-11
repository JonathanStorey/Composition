// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Identity.swift
// dependencies: [Extensions/Date.swift, Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/EncryptedStorage.swift, PropertyWrappers/SyncedStorage.swift]
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services]

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Security

/// The identities for scopes that outlive views and scenes, each created on first read.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
enum Identities {

    /// Kept in the private iCloud database, where the first identity to arrive wins on every device, seeded on first read.
    static let account: SyncedStorage<UUID?> = seeded(SyncedStorage("Composition.Identity.account", .first))

    /// Kept in this device's Keychain, or the install's when the Keychain refuses it.
    static let device: UUID = identity(in: .localOnly, or: install)

    /// Kept in Application Support and excluded from backup.
    static let install: UUID = identity(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "Identity"))

    /// Kept in the private iCloud database and renewed by every ping.
    static let iCloud: SyncedStorage<UUID?> = SyncedStorage("Composition.Identity.iCloud")

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

    /// Gives the storage a new identity to offer iCloud when it has none, such as on first launch or after the iCloud account changes.
    @discardableResult static func seeded(_ storage: SyncedStorage<UUID?>) -> SyncedStorage<UUID?> {
        if storage.wrappedValue == nil { storage.wrappedValue = .timestamp }
        return storage
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

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

/// A version 7 UUID created on first read and shared by every wrapper of its scope, from a single view to the user's iCloud account.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct Identity: DynamicProperty {

    /// How widely an identity is shared and how long it lasts, from shortest to longest, ending with the last round trip to iCloud.
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

        /// Shared by every device and app on the user's iCloud account, never renewed, and zero until it first reaches iCloud.
        case account

        /// Renewed by every refresh that makes a round trip to iCloud, and zero until the first one.
        case iCloud
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
        switch scope {
        case .account: Identities.account.lastSynced
        case .iCloud: Identities.iCloud.lastSynced
        case .device, .install, .launch, .scene, .view: Date(timestamp: wrappedValue)
        }
    }

    /// The wrapper itself, for its sync status and refresh.
    public var projectedValue: Identity {
        self
    }

    /// The status of the identity's last sync, which is always a success at its creation for scopes that never sync.
    public var status: SyncStatus {
        switch scope {
        case .account: Identities.account.status
        case .iCloud: Identities.iCloud.status
        case .device, .install, .launch, .scene, .view: .success(Date(timestamp: wrappedValue) ?? .distantPast)
        }
    }

    /// The identity, created on first read and reused for as long as the scope lives.
    public var wrappedValue: UUID {
        switch scope {
        case .account: Identities.account.syncedValue ?? .zero
        case .device: Identities.device
        case .iCloud: Identities.iCloud.syncedValue ?? .zero
        case .install: Identities.install
        case .launch: Identities.launch
        case .scene: storedSceneIdentity()
        case .view: viewIdentity
        }
    }

    /// Brings the identity up to date: a new identity for a view or scene, a round trip for iCloud, a fetch for the account until it arrives, and nothing for scopes fixed for their lifetime.
    public func refresh() {
        switch scope {
        case .account: Identities.seeded(Identities.account).refresh()
        case .device, .install, .launch: break
        case .iCloud:
            Identities.iCloud.wrappedValue = .timestamp
            Identities.iCloud.refresh()
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
