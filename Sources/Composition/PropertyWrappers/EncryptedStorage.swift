// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/EncryptedStorage.swift
// dependencies: [PropertyWrappers/StorageChanges.swift]

// MARK: - Foundation + Observation + Security

#if canImport(Foundation) && canImport(Observation) && canImport(Security)
import Foundation
import Observation
import Security

/// Reads and writes a value encrypted in the Keychain like `AppStorage`, kept on this device only or synced through iCloud Keychain.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct EncryptedStorage<Value: Codable & Sendable>: Sendable {

    /// The value returned when nothing is stored.
    public let defaultValue: Value
    /// The account name the value is stored under.
    public let key: String
    /// Where the Keychain keeps the value.
    public let location: Location
    /// The service name that groups this wrapper's values.
    public let service: String
    private let changes: StorageChanges

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String, _ location: Location = .localOnly, service: String = Bundle.main.bundleIdentifier ?? "Composition") {
        self.defaultValue = wrappedValue
        self.key = key
        self.location = location
        self.service = service
        self.changes = StorageChanges(item: ["Keychain", service, key, "\(location)"])
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String, _ location: Location = .localOnly, service: String = Bundle.main.bundleIdentifier ?? "Composition") where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key, location, service: service)
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value {
        get {
            changes.track()
            let query: [CFString: Any] = item.merging([kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true]) { $1 }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data: Data = result as? Data, let value: Value = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            defer { changes.post() }
            guard let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) else {
                SecItemDelete(item as CFDictionary)
                return
            }
            let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: location.accessibility]
            guard SecItemUpdate(item as CFDictionary, attributes as CFDictionary) == errSecItemNotFound else { return }
            SecItemAdd(item.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    /// The attributes that identify this wrapper's Keychain item.
    private var item: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key, kSecAttrSynchronizable: location == .iCloud, kSecUseDataProtectionKeychain: usesDataProtectionKeychain]
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension EncryptedStorage {

    /// Where the Keychain keeps a value.
    enum Location: Hashable, Sendable {

        /// Kept on this device only, never synced, backed up, or restored onto another device.
        case localOnly

        /// Synced to the user's other devices through iCloud Keychain.
        case iCloud

        /// The Keychain accessibility that matches the location.
        fileprivate var accessibility: CFString {
            switch self {
            case .localOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .iCloud: kSecAttrAccessibleAfterFirstUnlock
            }
        }
    }
}

/// Whether to use the data protection keychain, which macOS needs for local and iCloud items but only grants to apps signed with an entitlement for it.
fileprivate let usesDataProtectionKeychain: Bool = {
    #if os(macOS)
    guard let task: SecTask = SecTaskCreateFromSelf(nil) else { return false }
    return ["com.apple.application-identifier", "keychain-access-groups"].contains { SecTaskCopyValueForEntitlement(task, $0 as CFString, nil) != nil }
    #else
    return true
    #endif
}()
#endif

// MARK: - Foundation + Observation + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension EncryptedStorage {

    /// A binding to the stored value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
