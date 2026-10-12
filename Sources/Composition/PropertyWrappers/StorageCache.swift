// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageCache.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

/// Values decoded from stored JSON, remembered by the data they came from so reading unchanged data again skips the decoder, and dropped when memory runs low.
enum StorageCache {

    /// The decoded values, keyed by the data they came from.
    nonisolated(unsafe) private static let values: NSCache<NSData, Decoded> = NSCache()

    /// The value the data decodes to, taken from the cache when the same data was decoded as the same type before.
    static func decode<V: Decodable & Sendable>(_ type: V.Type, from data: Data) -> V? {
        if let value: V = values.object(forKey: data as NSData)?.value as? V { return value }
        guard let value: V = try? JSONDecoder().decode(V.self, from: data) else { return nil }
        values.setObject(Decoded(value), forKey: data as NSData)
        return value
    }
}

/// A decoded value, boxed so `NSCache` can hold it.
fileprivate final class Decoded: Sendable {

    let value: any Sendable

    /// Boxes the value.
    init(_ value: any Sendable) {
        self.value = value
    }
}
#endif
