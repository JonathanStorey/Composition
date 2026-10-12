// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Identity.swift
// dependencies: [Extensions/Date.swift, Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/EncryptedStorage.swift, PropertyWrappers/SyncedStorage.swift]
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, com.apple.security.network.client]

// MARK: - CloudKit + Foundation + Network + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Network) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Network
import Observation
import os
import Security

/// The identities for scopes that outlive views and scenes, each created on first read.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
enum Identities {

    /// Kept in this device's Keychain, or the install's when the Keychain refuses it.
    static let device: UUID = identity(or: install)

    /// Kept in Application Support and excluded from backup.
    static let install: UUID = identity(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "Identity"))

    /// Kept in the private iCloud database and renewed by every ping.
    static let iCloud: SyncedStorage<UUID?> = SyncedStorage("Composition.Identity.iCloud")

    /// Kept on the device and renewed by every confirmed connection to the internet.
    static let internet: InternetConnection = InternetConnection()

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

    /// Reads the identity stored in this device's Keychain, or stores a new one there, returning the fallback when the Keychain refuses it.
    private static func identity(or fallback: @autoclosure () -> UUID) -> UUID {
        let storage: EncryptedStorage<UUID?> = EncryptedStorage("localOnly", .thisDevice, service: "Composition.Identity")
        if let identity: UUID = storage.wrappedValue, identity.version == 7 { return identity }
        storage.wrappedValue = .timestamp
        return storage.wrappedValue ?? fallback()
    }
}

/// Confirms internet access by loading a page only a real connection returns, on refresh and whenever the network becomes usable, keeping the last success on the device.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class InternetConnection: Observable, Sendable {

    private let key: String
    private let monitor: OSAllocatedUnfairLock<NWPathMonitor?> = OSAllocatedUnfairLock(uncheckedState: nil)
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let state: OSAllocatedUnfairLock<(identity: UUID, status: SyncStatus)>
    private let url: URL

    /// Restores the last confirmed connection kept under the key, starting at its success, or at unknown before the first.
    init(checking url: URL = URL(string: "https://www.apple.com/library/test/success.html")!, storedUnder key: String = "Composition.Identity.internet") {
        let identity: UUID = UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:)) ?? .zero
        self.key = key
        self.state = OSAllocatedUnfairLock(initialState: (identity, Date(timestamp: identity).map(SyncStatus.success) ?? .unknown))
        self.url = url
    }

    /// Loads the URL, throwing the network's error, or a bad server response when a captive portal or anything but a page saying "Success" answers.
    private static func load(_ url: URL) async throws {
        let request: URLRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)
        guard ((response as? HTTPURLResponse)?.statusCode ?? 200) == 200, String(decoding: data, as: UTF8.self).contains("Success") else { throw URLError(.badServerResponse) }
    }

    /// The identity of the last confirmed connection, or zero before the first, watching the network from the first read.
    var identity: UUID {
        registrar.access(self, keyPath: \.revision)
        watch()
        return state.withLock { $0.identity }
    }

    /// The status of the last check.
    var status: SyncStatus {
        registrar.access(self, keyPath: \.revision)
        return state.withLock { $0.status }
    }

    /// A placeholder property that observers track in place of the identity and status.
    private var revision: Void { () }

    /// Loads the page in the background, moving the status to syncing and then to success with a new identity, or to failure, returning `nil` when a check is already under way.
    @discardableResult func confirm() -> Task<Void, Never>? {
        let starts: Bool = update { state in
            if case .syncing = state.status { return false }
            state.status = .syncing
            return true
        }
        guard starts else { return nil }
        return Task {
            do {
                try await Self.load(url)
                let identity: UUID = .timestamp
                UserDefaults.standard.set(identity.uuidString, forKey: key)
                update { $0 = (identity, .success(Date(timestamp: identity) ?? .now)) }
            } catch {
                update { $0.status = .failure(error) }
            }
        }
    }

    /// Changes the state and tells observers, returning the change's result.
    @discardableResult private func update<R: Sendable>(_ change: @Sendable (inout (identity: UUID, status: SyncStatus)) -> R) -> R {
        registrar.withMutation(of: self, keyPath: \.revision) { state.withLock(change) }
    }

    /// Starts watching the network on the first call, confirming access whenever the path becomes usable and failing as offline when it doesn't.
    private func watch() {
        monitor.withLockUnchecked { monitor in
            guard monitor == nil else { return }
            let created: NWPathMonitor = NWPathMonitor()
            created.pathUpdateHandler = { [weak self] path in
                if path.status == .satisfied {
                    self?.confirm()
                } else {
                    self?.update { $0.status = .failure(URLError(.notConnectedToInternet)) }
                }
            }
            created.start(queue: DispatchQueue(label: "Composition.InternetConnection"))
            monitor = created
        }
    }
}
#endif

// MARK: - CloudKit + Foundation + Network + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Network) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

/// A version 7 UUID created on first read and shared by every wrapper of its scope, from a single view to the whole device, or renewed by each round trip to iCloud or the internet.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct Identity: DynamicProperty {

    /// How widely an identity is shared and how long it lasts, from shortest to longest, ending with the last round trips to iCloud and the internet.
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

        /// Renewed by every refresh that makes a round trip to iCloud, and zero until the first one.
        case iCloud

        /// Renewed whenever a check confirms the device reaches the internet, on refresh and whenever the network becomes usable, and zero until the first.
        case internet
    }

    private let scope: Scope
    @SceneStorage("Composition.Identity.scene") private var sceneIdentity: String?
    @State private var viewIdentity: UUID = .timestamp

    /// Creates an identity shared within the scope.
    public init(of scope: Scope) {
        self.scope = scope
    }

    /// The last time the identity synced, which is when it was created for scopes that never sync.
    public var lastSynced: Date? {
        switch scope {
        case .iCloud: Identities.iCloud.lastSynced
        case .device, .install, .internet, .launch, .scene, .view: Date(timestamp: wrappedValue)
        }
    }

    /// The wrapper itself, for its sync status and refresh.
    public var projectedValue: Identity {
        self
    }

    /// The status of the identity's last sync, which is always a success at its creation for scopes that never sync.
    public var status: SyncStatus {
        switch scope {
        case .iCloud: Identities.iCloud.status
        case .internet: Identities.internet.status
        case .device, .install, .launch, .scene, .view: .success(Date(timestamp: wrappedValue) ?? .distantPast)
        }
    }

    /// The identity, created on first read and reused for as long as the scope lives.
    public var wrappedValue: UUID {
        switch scope {
        case .device: Identities.device
        case .iCloud: Identities.iCloud.syncedValue ?? .zero
        case .install: Identities.install
        case .internet: Identities.internet.identity
        case .launch: Identities.launch
        case .scene: storedSceneIdentity()
        case .view: viewIdentity
        }
    }

    /// Brings the identity up to date: a new identity for a view or scene, a round trip for iCloud or the internet, and nothing for scopes fixed for their lifetime.
    public func refresh() {
        switch scope {
        case .device, .install, .launch: break
        case .iCloud:
            Identities.iCloud.wrappedValue = .timestamp
            Identities.iCloud.refresh()
        case .internet: Identities.internet.confirm()
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
