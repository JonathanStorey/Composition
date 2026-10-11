// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StableIdentifier.swift
// dependencies: [Extensions/String.swift, Extensions/UUID.swift, PropertyWrappers/EncryptedStorage.swift]

#if canImport(SwiftUI)
import SwiftUI
#if canImport(IOKit)
import IOKit
#endif

/// A UUID that stays the same for as long as its scope lives: a view, a scene, an install, or a device.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct StableIdentifier: DynamicProperty {

    /// The lifetime an identifier stays the same within.
    public enum Scope: Hashable, Sendable {

        /// Stays the same while the view keeps its identity, and is new for every view.
        case view

        /// Stays the same for the scene, survives state restoration, and is shared by every view in the scene.
        case scene

        /// Stays the same until the app is deleted, and is never backed up or restored onto another device.
        case install

        /// Stays the same across reinstalls, and is never restored onto another device.
        case device
    }

    /// The lifetime the identifier stays the same within.
    public let scope: Scope
    @SceneStorage("Composition.StableIdentifier.scene") private var sceneIdentifier: String?
    @State private var viewIdentifier: UUID = .timestamp

    /// Creates an identifier that stays the same within the scope.
    public init(for scope: Scope) {
        self.scope = scope
    }

    /// The device's identifier: the hardware UUID on macOS, and a local Keychain item elsewhere.
    static let device: UUID = deviceIdentifier() ?? install

    /// The install's identifier, stored in Application Support and excluded from backup.
    static let install: UUID = identifier(at: .applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Composition").appending(path: "StableIdentifier"))

    /// Reads the identifier stored at the URL, or stores a new one there, excluded from backup, when none can be read.
    static func identifier(at url: URL) -> UUID {
        if let contents: String = try? String(contentsOf: url, encoding: .utf8), let identifier: UUID = UUID(uuidString: contents.trimmed) { return identifier }
        let identifier: UUID = .timestamp
        var location: URL = url
        var values: URLResourceValues = URLResourceValues()
        values.isExcludedFromBackup = true
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? identifier.uuidString.write(to: url, atomically: true, encoding: .utf8)
        try? location.setResourceValues(values)
        return identifier
    }

    /// Reads the platform's device identifier, creating it when the platform allows, or `nil` when none is available.
    private static func deviceIdentifier() -> UUID? {
        #if canImport(IOKit)
        let service: io_service_t = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        let property: CFTypeRef? = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (property as? String).flatMap(UUID.init(uuidString:))
        #else
        let storage: EncryptedStorage<UUID?> = EncryptedStorage("device", service: "Composition.StableIdentifier")
        if let identifier: UUID = storage.wrappedValue { return identifier }
        storage.wrappedValue = .timestamp
        return storage.wrappedValue
        #endif
    }

    /// The identifier, created on first use and reused for as long as the scope lives.
    public var wrappedValue: UUID {
        switch scope {
        case .device: Self.device
        case .install: Self.install
        case .scene: storedSceneIdentifier()
        case .view: viewIdentifier
        }
    }

    /// Reads the scene's identifier, storing this view's identifier as the scene's when the scene has none yet.
    private func storedSceneIdentifier() -> UUID {
        if let identifier: UUID = sceneIdentifier.flatMap(UUID.init(uuidString:)) { return identifier }
        sceneIdentifier = viewIdentifier.uuidString
        return viewIdentifier
    }
}
#endif
