// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Timestamp.swift
// dependencies: [Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/EncryptedStorage.swift, Protocols/TimestampRepresentable.swift]

#if canImport(SwiftUI)
import SwiftUI

/// A version 7 UUID, or the date inside it, fixed on first read and shared by every wrapper in its scope.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct Timestamp<Value: TimestampRepresentable>: DynamicProperty {

    /// The lifetime a timestamp stays the same within.
    public enum Scope: Hashable, Sendable {

        /// Stays the same while the view keeps its identity, and is new for every view.
        case view

        /// Stays the same for the scene, survives state restoration, and is shared by every view in the scene.
        case scene

        /// Stays the same until the app is deleted, and is never backed up or restored onto another device.
        case install

        /// Stays the same across reinstalls, and is never restored onto another device.
        case device

        /// Stays the same across reinstalls, and moves to a new device with an encrypted backup.
        case backedUp

        /// Stays the same on every device signed in to the same iCloud account.
        case iCloud
    }

    /// The lifetime the timestamp stays the same within.
    public let scope: Scope
    @SceneStorage("Composition.Timestamp.scene") private var sceneIdentifier: String?
    @State private var viewIdentifier: UUID = .timestamp

    /// Creates a timestamp that stays the same within the scope.
    public init(_ scope: Scope) {
        self.scope = scope
    }

    /// Reads the identifier stored at the URL, or stores a new one there, excluded from backup, when none can be read.
    static func identifier(at url: URL) -> UUID {
        if let contents: String = try? String(contentsOf: url, encoding: .utf8), let identifier: UUID = UUID(uuidString: contents.trimmed), identifier.version == 7 { return identifier }
        let identifier: UUID = .timestamp
        var location: URL = url
        var values: URLResourceValues = URLResourceValues()
        values.isExcludedFromBackup = true
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? identifier.uuidString.write(to: url, atomically: true, encoding: .utf8)
        try? location.setResourceValues(values)
        return identifier
    }

    /// Reads the identifier stored in the Keychain at the location, or stores a new one there, returning the fallback when the Keychain refuses it.
    fileprivate static func identifier(in location: EncryptedStorage<UUID?>.Location, or fallback: @autoclosure () -> UUID) -> UUID {
        let storage: EncryptedStorage<UUID?> = EncryptedStorage("\(location)", location, service: "Composition.Timestamp")
        if let identifier: UUID = storage.wrappedValue, identifier.version == 7 { return identifier }
        storage.wrappedValue = .timestamp
        return storage.wrappedValue ?? fallback()
    }

    /// The timestamp, created on first read and reused for as long as the scope lives.
    public var wrappedValue: Value {
        Value(timestamp: identifier)!
    }

    /// The version 7 UUID for the scope.
    private var identifier: UUID {
        switch scope {
        case .backedUp: Identifiers.backedUp
        case .device: Identifiers.device
        case .iCloud: Identifiers.iCloud
        case .install: Identifiers.install
        case .scene: storedSceneIdentifier()
        case .view: viewIdentifier
        }
    }

    /// Reads the scene's identifier, storing this view's identifier as the scene's when the scene has none yet.
    private func storedSceneIdentifier() -> UUID {
        if let identifier: UUID = sceneIdentifier.flatMap(UUID.init(uuidString:)), identifier.version == 7 { return identifier }
        sceneIdentifier = viewIdentifier.uuidString
        return viewIdentifier
    }
}

/// The identifiers for scopes that outlive views and scenes, each created on first read and reused for the rest of the process.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate enum Identifiers {

    /// Kept in the Keychain and carried to new devices by encrypted backups, or the device's when the Keychain refuses it.
    static let backedUp: UUID = Timestamp<UUID>.identifier(in: .backedUp, or: device)

    /// Kept in this device's Keychain, or the install's when the Keychain refuses it.
    static let device: UUID = Timestamp<UUID>.identifier(in: .localOnly, or: install)

    /// Synced through iCloud Keychain, or the device's when the Keychain refuses it.
    static let iCloud: UUID = Timestamp<UUID>.identifier(in: .iCloud, or: device)

    /// Kept in Application Support and excluded from backup.
    static let install: UUID = Timestamp<UUID>.identifier(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "Timestamp"))
}
#endif
