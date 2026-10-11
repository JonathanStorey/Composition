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

    /// The value returned when nothing is stored.
    public let defaultValue: Value
    /// The key the value is stored under.
    public let key: String
    private let changes: StorageChanges

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
        self.changes = StorageChanges(item: ["iCloud", key], observing: [NSUbiquitousKeyValueStore.didChangeExternallyNotification])
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key)
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value {
        get {
            changes.track()
            guard let data: Data = NSUbiquitousKeyValueStore.default.data(forKey: key), let value: Value = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            defer { changes.post() }
            if let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) {
                NSUbiquitousKeyValueStore.default.set(data, forKey: key)
            } else {
                NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
            }
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
}
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
