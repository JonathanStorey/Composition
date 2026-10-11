// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/KeychainStorage.swift
// dependencies: []

#if canImport(Foundation) && canImport(Observation) && canImport(Security)
import Foundation
import Observation
import Security

/// Reads and writes a value in the Keychain, kept on this device or synced through iCloud Keychain, and refreshes every view that reads it when it changes.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct KeychainStorage<Value: Codable> {

    /// The account name the value is stored under.
    public let key: String
    /// Where the Keychain keeps the value.
    public let location: Location
    /// The service name that groups this wrapper's values.
    public let service: String
    private let changes: KeychainChanges

    /// Creates storage for the key in the service, kept in the location.
    public init(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "Composition", location: Location = .local) {
        self.key = key
        self.location = location
        self.service = service
        self.changes = KeychainChanges(item: [service, key, "\(location)"])
    }

    /// The stored value, or `nil` when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value? {
        get {
            _ = changes.count
            let query: [CFString: Any] = item.merging([kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true]) { $1 }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data: Data = result as? Data else { return nil }
            return try? JSONDecoder().decode(Value.self, from: data)
        }
        nonmutating set {
            defer { changes.post() }
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
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key, kSecAttrSynchronizable: location == .iCloud, kSecUseDataProtectionKeychain: KeychainChanges.usesDataProtectionKeychain]
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
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

/// Counts writes to one Keychain item, so every wrapper for that item refreshes the views that read it.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Observable
fileprivate final class KeychainChanges: NSObject {

    private let item: [String]
    private(set) var count: Int = 0

    init(item: [String]) {
        self.item = item
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: Self.name, object: nil)
    }

    /// Whether to use the data protection keychain, which macOS needs for local and iCloud items but only grants to entitled apps.
    static let usesDataProtectionKeychain: Bool = hasKeychainEntitlement()

    /// The notification every wrapper posts after writing, carrying the item it wrote.
    private static let name: Notification.Name = Notification.Name("Composition.KeychainStorage.didChange")

    /// Whether the process is signed with an entitlement that grants the data protection keychain, which only macOS can lack.
    private static func hasKeychainEntitlement() -> Bool {
        #if os(macOS)
        guard let task: SecTask = SecTaskCreateFromSelf(nil) else { return false }
        return ["com.apple.application-identifier", "keychain-access-groups"].contains { SecTaskCopyValueForEntitlement(task, $0 as CFString, nil) != nil }
        #else
        return true
        #endif
    }

    /// Tells every wrapper for this item that its value changed.
    func post() {
        NotificationCenter.default.post(name: Self.name, object: nil, userInfo: ["item": item])
    }

    /// Counts a change when the notification is for this item.
    @objc private func receive(_ notification: Notification) {
        guard notification.userInfo?["item"] as? [String] == item else { return }
        count += 1
    }
}
#endif
