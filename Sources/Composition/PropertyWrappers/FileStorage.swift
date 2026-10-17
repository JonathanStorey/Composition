// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/FileStorage.swift
// dependencies: [Extensions/FileManager.swift, Protocols/FileRepresentable.swift]

// MARK: - Foundation + Observation + os + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(UniformTypeIdentifiers)
import Foundation
import Observation
import os
import UniformTypeIdentifiers

/// Reads and writes a value like `AppStorage`, kept in its own file inside the location in its own format when it is `FileRepresentable` and as JSON otherwise, cached in memory, written in the background, and, in the locations another process or iCloud can change, reloaded when the file changes on disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct FileStorage<Value: Codable & Sendable>: Sendable {

    private let defaultValue: Value
    private let file: FileManager.CachedFile
    private let isRepresentable: Bool

    /// Creates storage for the path that returns the default value until something is stored, where a path without an extension, such as "Settings/theme", gets the preferred extension of the `FileRepresentable` type's content type or ".json", stopping on a path that could leave the location, and stopping debug builds on a path without an extension when the content type has none.
    public init(wrappedValue: Value, _ path: String, _ location: Location = .app) {
        let violation: String? = path.pathViolation
        precondition(violation == nil, violation ?? "")
        let representable: (any FileRepresentable.Type)? = Value.self as? any FileRepresentable.Type
        let defaultExtension: String? = if let representable { representable.contentType.preferredFilenameExtension } else { "json" }
        if defaultExtension == nil, !path.hasPathExtension { assertionFailure("The FileStorage path \"\(path)\" needs an extension, since \(Value.self)'s content type has no preferred one.") }
        self.defaultValue = wrappedValue
        self.file = location.file(defaultExtension.map { path.withPathExtension($0) } ?? path)
        self.isRepresentable = representable != nil
    }

    /// Creates storage for the path that returns `nil` until something is stored.
    public init(_ path: String, _ location: Location = .app) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, path, location)
    }

    /// The value kept in the file, or the default value when there is none or it can't be read, where setting `nil` removes the file.
    public var wrappedValue: Value {
        get {
            guard let data: Data = file.contents else { return defaultValue }
            let value: Value? = if isRepresentable {
                DecodedValues.decode(data) { try (Value.self as? any FileRepresentable.Type)?.init(fileContents: $0) as? Value }
            } else {
                DecodedValues.decode(data) { try JSONDecoder().decode(Value.self, from: $0) }
            }
            return value ?? defaultValue
        }
        nonmutating set {
            let mirror: Mirror = Mirror(reflecting: newValue)
            guard mirror.displayStyle != .optional || !mirror.children.isEmpty else { return file.write(nil) }
            let contents: Data? = if isRepresentable { try? (newValue as? any FileRepresentable)?.fileContents() } else { try? JSONEncoder().encode(newValue) }
            file.write(contents)
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// The folder a file is kept in.
    typealias Location = FileManager.Location
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate extension FileManager.Location {

    /// The shared file at the path inside the location, watched for changes on disk only where another process or iCloud can make them, and in iCloud kept on the device until iCloud is available.
    func file(_ path: String) -> FileManager.CachedFile {
        let url: URL = FileManager.default.url(for: self).appending(path: path)
        switch self {
        case .app, .caches, .temp:
            return FileManager.default.cachedFile(at: url)
        case .documents, .group:
            return FileManager.default.cachedFile(at: url, watched: true)
        case .iCloud, .iCloudDrive:
            let local: URL = FileManager.default.localFolder(for: self).appending(path: path)
            guard url != local else { return FileManager.default.cachedFile(at: local) }
            return FileManager.default.cachedFile(at: url, watched: true, ubiquitous: true, moving: local)
        }
    }
}

fileprivate extension String {

    /// A Boolean value indicating whether the path's last name has an extension.
    var hasPathExtension: Bool {
        split(separator: "/").last?.contains(".") == true
    }

    /// Why the path can't name a file inside its location, or `nil` when it can: a relative path of names, none empty or starting with ".".
    var pathViolation: String? {
        guard !hasPrefix("/"), split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") }) else { return "The FileStorage path \"\(self)\" must be relative, without empty components or ones starting with \".\"." }
        return nil
    }

    /// The path as given when its last name has an extension, or with the default extension added when it has none.
    func withPathExtension(_ defaultExtension: String) -> String {
        hasPathExtension ? self : "\(self).\(defaultExtension)"
    }
}

/// Values decoded from stored files, remembered by the data they came from so reading unchanged data again skips the decoder, and dropped when memory runs low.
fileprivate enum DecodedValues {

    /// The decoded values, keyed by the data they came from.
    nonisolated(unsafe) private static let cache: NSCache<NSData, DecodedValue> = NSCache()

    /// The value the decoder makes from the data, taken from the cache when the same data was decoded as the same type before.
    static func decode<V>(_ data: Data, with decoder: (Data) throws -> V?) -> V? {
        if let decoded: DecodedValue = cache.object(forKey: data as NSData), let value: V = decoded.value as? V { return value }
        guard let value: V = try? decoder(data) else { return nil }
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
#endif

// MARK: - Foundation + Observation + os + SwiftUI + UniformTypeIdentifiers

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension FileStorage {

    /// A binding to the value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
