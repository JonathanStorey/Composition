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

    private let changes: StorageChanges
    private let defaultValue: Value
    private let key: String

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
        self.changes = StorageChanges(item: ["UserDefaults", key], observing: [UserDefaults.didChangeNotification])
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key)
    }

    /// The user defaults limit that writing the data would break, or `nil` when it fits under 4 MB.
    static func limitViolation(writing data: Data) -> String? {
        data.count < 4_194_304 ? nil : "UserStorage value is \(data.count) bytes, over the 4 MB user defaults allows."
    }

    /// Whether the value is a property-list type that user defaults stores as is, so `AppStorage` can share its key.
    private static func isPropertyList(_ value: Value) -> Bool {
        switch value as Any {
        case is Bool, is Data, is Date, is Double, is Int, is String: true
        default: false
        }
    }

    /// The stored value, or the default value when nothing is stored; setting `nil` removes it, and debug builds stop on a value of 4 MB or more.
    public var wrappedValue: Value {
        get {
            changes.track()
            switch UserDefaults.standard.object(forKey: key) {
            case let value as Value: return value
            case let data as Data: return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
            default: return defaultValue
            }
        }
        nonmutating set {
            defer { changes.post() }
            guard let data: Data = try? JSONEncoder().encode(newValue), data != Data("null".utf8) else { return UserDefaults.standard.removeObject(forKey: key) }
            assert(Self.limitViolation(writing: data) == nil, Self.limitViolation(writing: data) ?? "")
            UserDefaults.standard.set(Self.isPropertyList(newValue) ? newValue : data, forKey: key)
        }
    }
}

/// Another name for `UserStorage` that says which store it uses.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public typealias UserDefaultsStorage<Value: Codable & Sendable> = UserStorage<Value>
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
