// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Identity.swift
// dependencies: [Extensions/Date.swift, Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/CloudStorage.swift, PropertyWrappers/EncryptedStorage.swift, PropertyWrappers/UserStorage.swift]
// permissions: [com.apple.developer.ubiquity-kvstore-identifier, com.apple.security.application-groups]

// MARK: - Foundation + Observation + os + Security

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Observation
import os
import Security

/// The state of a value's last sync, shaped like `Result`, with the date of the last success.
public enum SyncStatus: Hashable, Sendable {

    /// Not synced since launch, and no earlier success is known.
    case unknown

    /// Waiting on a sync that is under way.
    case syncing

    /// Synced successfully at the date.
    case success(Date)

    /// The last sync failed for the reason.
    case failure(SyncError)
}

/// Why a sync with iCloud failed.
public enum SyncError: Error, Hashable, Sendable {

    /// No iCloud account is signed in, or iCloud is turned off for the app.
    case noAccount

    /// The app has used up its iCloud key-value storage.
    case quotaExceeded

    /// iCloud refused the sync, such as when the app lacks the key-value storage entitlement.
    case unavailable
}

/// The identities for scopes that outlive views and scenes, each created on first read.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
enum Identities {

    /// Kept in the Keychain and carried to new devices by encrypted backups, or the device's when the Keychain refuses it.
    static let backedUp: UUID = identity(in: .backedUp, or: device)

    /// Kept in this device's Keychain, or the install's when the Keychain refuses it.
    static let device: UUID = identity(in: .localOnly, or: install)

    /// Kept in Application Support and excluded from backup.
    static let install: UUID = identity(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "Identity"))

    /// Created when the app launches and gone when it quits.
    static let launch: UUID = .timestamp

    /// Reads the identity shared by every app and extension in the app group, or stores a new one there, returning the install's when the group refuses it.
    static func appGroup(_ identifier: String) -> UUID {
        let storage: UserStorage<UUID?> = UserStorage("Composition.Identity", .appGroup(identifier))
        if let identity: UUID = storage.wrappedValue, identity.version == 7 { return identity }
        storage.wrappedValue = .timestamp
        return storage.wrappedValue ?? install
    }

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

/// The identity synced through iCloud key-value storage, cached on the device, with the status of its last sync.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class CloudIdentity: NSObject, Observable, Sendable {

    private let cache: UserStorage<UUID?> = UserStorage("Composition.Identity.iCloud")
    private let cloud: CloudStorage<UUID?> = CloudStorage("Composition.Identity")
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let state: OSAllocatedUnfairLock<SyncStatus>
    private let synced: UserStorage<Date?> = UserStorage("Composition.Identity.iCloud.lastSynced")

    /// Restores the last successful sync, and starts watching iCloud for changes.
    private override init() {
        let lastSynced: Date? = FileManager.default.ubiquityIdentityToken == nil ? nil : synced.wrappedValue
        self.state = OSAllocatedUnfairLock(initialState: lastSynced.map(SyncStatus.success) ?? .unknown)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: .NSUbiquityIdentityDidChange, object: nil)
    }

    /// The identity every wrapper of the iCloud scope shares.
    static let shared: CloudIdentity = CloudIdentity()

    /// The identity for the signed-in iCloud account, created when the account has none, or zero when no account is signed in.
    var identity: UUID {
        guard FileManager.default.ubiquityIdentityToken != nil else { return .zero }
        if let identity: UUID = cloud.wrappedValue, identity.version == 7 {
            if cache.wrappedValue != identity { cache.wrappedValue = identity }
            return identity
        }
        let identity: UUID = cache.wrappedValue.flatMap { $0.version == 7 ? $0 : nil } ?? .timestamp
        cloud.wrappedValue = identity
        cache.wrappedValue = identity
        return identity
    }

    /// The last time a sync succeeded, kept on the device.
    var lastSynced: Date? {
        synced.wrappedValue
    }

    /// The status of the last sync.
    var status: SyncStatus {
        registrar.access(self, keyPath: \.status)
        return state.withLock { $0 }
    }

    /// Syncs with iCloud in the background, moving the status to syncing and then to success or failure.
    func refresh() {
        guard FileManager.default.ubiquityIdentityToken != nil else { return update(.failure(.noAccount)) }
        update(.syncing)
        guard NSUbiquitousKeyValueStore.default.synchronize() else { return update(.failure(.unavailable)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            if state.withLock({ $0 }) == .syncing { update(.success(.now)) }
        }
    }

    /// Updates the status after a change from iCloud: a new account, a full store, or new values from another device.
    @objc private func receive(_ notification: Notification) {
        switch notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
        case NSUbiquitousKeyValueStoreQuotaViolationChange?:
            update(.failure(.quotaExceeded))
        case NSUbiquitousKeyValueStoreAccountChange?, nil:
            cache.wrappedValue = nil
            update(FileManager.default.ubiquityIdentityToken == nil ? .failure(.noAccount) : .success(.now))
        default:
            update(.success(.now))
        }
    }

    /// Sets the status, keeping the date of a success on the device.
    private func update(_ status: SyncStatus) {
        if case .success(let date) = status { synced.wrappedValue = date }
        registrar.withMutation(of: self, keyPath: \.status) {
            state.withLock { $0 = status }
        }
    }
}
#endif

// MARK: - Foundation + Observation + os + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

/// A version 7 UUID created on first read and shared by every wrapper of its scope, from a single view to every device on an iCloud account.
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

        /// Stays the same for every app and extension in the app group with this identifier.
        case appGroup(String)

        /// Stays the same across reinstalls, and is never restored onto another device.
        case device

        /// Stays the same across reinstalls, and moves to a new device with an encrypted backup.
        case backedUp

        /// Stays the same on every device signed in to the iCloud account, changes with the account, and is zero when none is signed in.
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

    /// The last time the identity synced, or when it was created for scopes that never sync.
    public var lastSynced: Date? {
        scope == .iCloud ? CloudIdentity.shared.lastSynced : Date(timestamp: wrappedValue)
    }

    /// The wrapper itself, for its sync status and refresh.
    public var projectedValue: Identity {
        self
    }

    /// The status of the identity's last sync, which is always a success at its creation for scopes that never sync.
    public var status: SyncStatus {
        scope == .iCloud ? CloudIdentity.shared.status : .success(Date(timestamp: wrappedValue) ?? .distantPast)
    }

    /// The identity, created on first read and reused for as long as the scope lives.
    public var wrappedValue: UUID {
        switch scope {
        case .appGroup(let identifier): Identities.appGroup(identifier)
        case .backedUp: Identities.backedUp
        case .device: Identities.device
        case .iCloud: CloudIdentity.shared.identity
        case .install: Identities.install
        case .launch: Identities.launch
        case .scene: storedSceneIdentity()
        case .view: viewIdentity
        }
    }

    /// Syncs the identity with its source in the background, which only the iCloud scope has.
    public func refresh() {
        if scope == .iCloud { CloudIdentity.shared.refresh() }
    }

    /// Reads the scene's identity, storing this view's identity as the scene's when the scene has none yet.
    private func storedSceneIdentity() -> UUID {
        if let identity: UUID = sceneIdentity.flatMap(UUID.init(uuidString:)), identity.version == 7 { return identity }
        sceneIdentity = viewIdentity.uuidString
        return viewIdentity
    }
}
#endif
