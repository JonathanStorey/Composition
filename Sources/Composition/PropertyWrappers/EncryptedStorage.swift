// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/EncryptedStorage.swift
// dependencies: []

// MARK: - Foundation + Observation + os + Security

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Observation
import os
import Security

/// Reads and writes a value encrypted in the Keychain like `AppStorage`, synced through iCloud Keychain or kept on this device.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct EncryptedStorage<Value: Codable & Sendable>: Sendable {

    private let changes: StorageChanges
    private let defaultValue: Value
    private let key: String
    private let location: Location
    private let service: String

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String, _ location: Location = .iCloud, service: String = Bundle.main.bundleIdentifier ?? "Composition") {
        self.defaultValue = wrappedValue
        self.key = key
        self.location = location
        self.service = service
        self.changes = StorageChanges(item: ["Keychain", service, key, "\(location == .iCloud)"])
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String, _ location: Location = .iCloud, service: String = Bundle.main.bundleIdentifier ?? "Composition") where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key, location, service: service)
    }

    /// The Keychain limit that writing the data would break, or `nil` when it fits in 16,777,110 bytes.
    static func limitViolation(writing data: Data) -> String? {
        data.count <= 16_777_110 ? nil : "EncryptedStorage value is \(data.count) bytes, over the 16,777,110 the Keychain holds."
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it, and debug builds stop on a value past the Keychain's limit.
    public var wrappedValue: Value {
        get {
            changes.track()
            guard let data: Data = keychainReads.withLock({ $0[identity] }) ?? read(), let value: Value = DecodedValues.decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            defer {
                keychainReads.withLock { _ = $0.removeValue(forKey: identity) }
                changes.post()
            }
            guard let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) else {
                SecItemDelete(item as CFDictionary)
                return
            }
            assert(Self.limitViolation(writing: data) == nil, Self.limitViolation(writing: data) ?? "")
            let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: location.accessibility]
            guard SecItemUpdate(item as CFDictionary, attributes as CFDictionary) == errSecItemNotFound else { return }
            SecItemAdd(item.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    /// The strings that name this wrapper's Keychain item.
    private var identity: [String] {
        ["Keychain", service, key, "\(location == .iCloud)"]
    }

    /// The attributes that identify this wrapper's Keychain item.
    private var item: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key, kSecAttrSynchronizable: location == .iCloud, kSecUseDataProtectionKeychain: usesDataProtectionKeychain]
    }

    /// Reads the item's data from the Keychain, remembering it, or its absence, for the next read.
    private func read() -> Data? {
        let query: [CFString: Any] = item.merging([kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true]) { $1 }
        var result: CFTypeRef?
        let data: Data? = SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
        keychainReads.withLock { $0[identity] = data }
        return data
    }
}

/// Another name for `EncryptedStorage` that says which store it uses.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public typealias KeychainStorage<Value: Codable & Sendable> = EncryptedStorage<Value>

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension EncryptedStorage {

    /// Where the Keychain keeps a value.
    enum Location: Hashable, Sendable {

        /// Synced to the user's other devices through iCloud Keychain, or kept on this device when iCloud Keychain is off.
        case iCloud

        /// Kept on this device only, never synced, backed up, or restored onto another device.
        case device

        /// The Keychain accessibility that matches the location.
        fileprivate var accessibility: CFString {
            switch self {
            case .iCloud: kSecAttrAccessibleAfterFirstUnlock
            case .device: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
        }
    }
}

/// Values decoded from stored JSON, remembered by the data they came from so reading unchanged data again skips the decoder, and dropped when memory runs low.
fileprivate enum DecodedValues {

    /// The decoded values, keyed by the data they came from.
    nonisolated(unsafe) private static let cache: NSCache<NSData, DecodedValue> = NSCache()

    /// The value the data decodes to, taken from the cache when the same data was decoded as the same type before.
    static func decode<V: Decodable>(_ type: V.Type, from data: Data) -> V? {
        if let decoded: DecodedValue = cache.object(forKey: data as NSData), let value: V = decoded.value as? V { return value }
        guard let value: V = try? JSONDecoder().decode(V.self, from: data) else { return nil }
        cache.setObject(DecodedValue(value), forKey: data as NSData)
        return value
    }
}

/// A decoded value, boxed so `NSCache` can hold it.
fileprivate final class DecodedValue {

    let value: Any

    /// Boxes the value.
    init(_ value: Any) {
        self.value = value
    }
}

/// The data last read from or found missing in the Keychain for each item, so repeated reads skip the Keychain until a wrapper writes the item.
fileprivate let keychainReads: OSAllocatedUnfairLock<[[String]: Data?]> = OSAllocatedUnfairLock(initialState: [:])

/// Whether to use the data protection keychain, which macOS needs for iCloud and device-only items but only grants to apps signed with an entitlement for it.
fileprivate let usesDataProtectionKeychain: Bool = {
    #if os(macOS)
    guard let task: SecTask = SecTaskCreateFromSelf(nil) else { return false }
    return ["com.apple.application-identifier", "keychain-access-groups"].contains { SecTaskCopyValueForEntitlement(task, $0 as CFString, nil) != nil }
    #else
    return true
    #endif
}()

/// Tells observers, such as a view's body, when a stored item changes, whether a wrapper wrote it or the system changed it.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate final class StorageChanges: NSObject, Observable, Sendable {

    private let item: [String]
    private let registrar: ObservationRegistrar = ObservationRegistrar()

    /// Starts watching the item for writes from any wrapper, and for every notification with one of the names.
    init(item: [String], observing names: [Notification.Name] = []) {
        self.item = item
        super.init()
        for name: Notification.Name in [Self.name] + names {
            NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: name, object: nil)
        }
    }

    /// The notification every wrapper posts after writing, carrying the item it wrote.
    private static let name: Notification.Name = Notification.Name("Composition.StorageChanges.didChange")

    /// A placeholder property that observers track in place of the stored value.
    private var revision: Void { () }

    /// Tells every wrapper for this item that its value changed.
    func post() {
        NotificationCenter.default.post(name: Self.name, object: nil, userInfo: ["item": item])
    }

    /// Registers the current observer for changes to the item.
    func track() {
        registrar.access(self, keyPath: \.revision)
    }

    /// Notifies observers when the notification is a system change or a write to this item.
    @objc private func receive(_ notification: Notification) {
        guard notification.name != Self.name || notification.userInfo?["item"] as? [String] == item else { return }
        registrar.withMutation(of: self, keyPath: \.revision) {}
    }
}
#endif

// MARK: - Foundation + Observation + os + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension EncryptedStorage {

    /// A binding to the stored value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
