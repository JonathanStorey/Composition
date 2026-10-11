// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/KeychainStorage.swift
// dependencies: []

#if canImport(Foundation) && canImport(Security)
import Foundation
import Security

/// Reads and writes a value in the Keychain, kept on this device or synced through iCloud Keychain.
@propertyWrapper
public struct KeychainStorage<Value: Codable> {

    /// The account name the value is stored under.
    public let key: String
    /// Where the Keychain keeps the value.
    public let location: Location
    /// The service name that groups this wrapper's values.
    public let service: String

    /// Creates storage for the key in the service, kept in the location.
    public init(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "Composition", location: Location = .local) {
        self.key = key
        self.location = location
        self.service = service
    }

    /// The stored value, or `nil` when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value? {
        get {
            let query: [CFString: Any] = item.merging([kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true]) { $1 }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data: Data = result as? Data else { return nil }
            return try? JSONDecoder().decode(Value.self, from: data)
        }
        nonmutating set {
            guard let value: Value = newValue, let data: Data = try? JSONEncoder().encode(value) else {
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
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key, kSecAttrSynchronizable: location == .iCloud]
    }
}

public extension KeychainStorage {

    /// Where the Keychain keeps a value.
    enum Location: Hashable, Sendable {

        /// Kept on this device only, never synced or restored onto another device.
        case local

        /// Synced to the user's other devices through iCloud Keychain.
        case iCloud

        /// The Keychain accessibility that matches the location.
        fileprivate var accessibility: CFString {
            switch self {
            case .local: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .iCloud: kSecAttrAccessibleAfterFirstUnlock
            }
        }
    }
}

extension KeychainStorage: Sendable {}
#endif
