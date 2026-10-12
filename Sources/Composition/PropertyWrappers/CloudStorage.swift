// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/CloudStorage.swift
// dependencies: [PropertyWrappers/StorageChanges.swift]
// permissions: [com.apple.developer.ubiquity-kvstore-identifier]

// MARK: - Foundation + Observation

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation

/// Reads and writes a value in iCloud key-value storage like `AppStorage`, synced to the user's other devices.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct CloudStorage<Value: Codable & Sendable>: Sendable {

    private let changes: StorageChanges
    private let defaultValue: Value
    private let key: String

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
        self.changes = StorageChanges(item: ["iCloud", key], observing: [NSUbiquitousKeyValueStore.didChangeExternallyNotification])
        _ = synchronizesAtLaunch
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key)
    }

    /// The iCloud key-value storage limit that writing the data under the key would break, or `nil` when it fits: 64 bytes per key, 1,024 keys, and 1 MB in total.
    static func limitViolation(writing data: Data, to key: String, in stored: [String: Any]) -> String? {
        let values: [String: Any] = stored.merging([key: data]) { $1 }
        let size: Int = (try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).count) ?? 0
        if key.utf8.count > 64 { return "CloudStorage key \"\(key)\" is \(key.utf8.count) bytes, over iCloud's limit of 64." }
        if values.count > 1_024 { return "CloudStorage would hold \(values.count) keys, over iCloud's limit of 1,024." }
        if size > 1_048_576 { return "CloudStorage would hold \(size) bytes, over iCloud's limit of 1 MB." }
        return nil
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it, and debug builds stop on a write past iCloud's limits.
    public var wrappedValue: Value {
        get {
            changes.track()
            guard let data: Data = NSUbiquitousKeyValueStore.default.data(forKey: key), let value: Value = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            defer { changes.post() }
            if let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) {
                assert(Self.limitViolation(writing: data, to: key, in: NSUbiquitousKeyValueStore.default.dictionaryRepresentation) == nil, Self.limitViolation(writing: data, to: key, in: NSUbiquitousKeyValueStore.default.dictionaryRepresentation) ?? "")
                NSUbiquitousKeyValueStore.default.set(data, forKey: key)
            } else {
                NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
            }
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
}

/// Asks iCloud for the latest values once per launch, as Apple advises, so changes made on other devices arrive and notify.
fileprivate let synchronizesAtLaunch: Bool = NSUbiquitousKeyValueStore.default.synchronize()
#endif

// MARK: - Foundation + Observation + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension CloudStorage {

    /// A binding to the stored value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
