// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/UserStorage.swift
// dependencies: [PropertyWrappers/StorageChanges.swift]

// MARK: - Foundation + Observation

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation

/// Reads and writes a value in user defaults like `AppStorage`, for any `Codable` value and from anywhere, not only views.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct UserStorage<Value: Codable & Sendable>: Sendable {

    /// The value returned when nothing is stored.
    public let defaultValue: Value
    /// The key the value is stored under.
    public let key: String
    /// The name of the user defaults suite the value is stored in, or `nil` for the standard user defaults.
    public let suite: String?
    private let changes: StorageChanges

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String, suite: String? = nil) {
        self.defaultValue = wrappedValue
        self.key = key
        self.suite = suite
        self.changes = StorageChanges(item: ["UserDefaults", suite ?? "", key], observing: [UserDefaults.didChangeNotification])
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String, suite: String? = nil) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key, suite: suite)
    }

    /// Whether the value is a property-list type that user defaults stores as is, so `AppStorage` can share its key.
    private static func isPropertyList(_ value: Value) -> Bool {
        switch value as Any {
        case is Bool, is Data, is Date, is Double, is Int, is String: true
        default: false
        }
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value {
        get {
            changes.track()
            switch store.object(forKey: key) {
            case let value as Value: return value
            case let data as Data: return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
            default: return defaultValue
            }
        }
        nonmutating set {
            defer { changes.post() }
            guard let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) else { return store.removeObject(forKey: key) }
            store.set(Self.isPropertyList(newValue) ? newValue : data, forKey: key)
        }
    }

    /// The user defaults for the suite.
    private var store: UserDefaults {
        suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
#endif

// MARK: - Foundation + Observation + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension UserStorage {

    /// A binding to the stored value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
