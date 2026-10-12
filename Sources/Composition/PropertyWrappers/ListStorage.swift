// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/ListStorage.swift
// dependencies: [PropertyWrappers/SyncedStorage.swift]
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, UIBackgroundModes]

// Setup in Xcode: follow the steps at the top of SyncedStorage.swift, since ListStorage syncs through the same engine and record type.

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import CloudKit
import Foundation

/// Reads and writes a list of identifiable items like `AppStorage`, kept on the device and synced through the user's private iCloud database one item at a time, so edits to different items on different devices all survive.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct ListStorage<Value: Codable & Identifiable & Sendable>: Sendable {

    private let descriptors: [SortDescriptor<Value>]
    private let filter: Predicate<Value>?
    private let key: String

    /// Creates storage for the key whose items, starting empty, read through the filter and sorted by the descriptors, or in the order written without them, stopping on a key that contains "/" or starts with "_".
    public init(_ key: String, filter: Predicate<Value>? = nil, sort descriptors: [SortDescriptor<Value>] = []) {
        precondition(!key.contains("/") && !key.hasPrefix("_"), "The ListStorage key \"\(key)\" can't contain \"/\", which separates the list from its items, or start with \"_\", which CloudKit reserves.")
        self.descriptors = descriptors
        self.filter = filter
        self.key = key
    }

    /// Creates storage for the key whose items, starting empty, read through the filter and sorted by the key path.
    public init<C: Comparable>(_ key: String, filter: Predicate<Value>? = nil, sort keyPath: KeyPath<Value, C> & Sendable, order: SortOrder = .forward) {
        self.init(key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// Creates storage for the key whose items, starting empty, read through the filter and sorted by the optional key path.
    public init<C: Comparable>(_ key: String, filter: Predicate<Value>? = nil, sort keyPath: KeyPath<Value, C?> & Sendable, order: SortOrder = .forward) {
        self.init(key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// The items kept under the key in the order written, each decoded with its position.
    private static func stored(under key: String) -> [(key: String, item: Item)] {
        SyncEngine.shared.values(under: key).compactMap { itemKey, data in DecodedValues.decode(Item.self, from: data).map { (itemKey, $0) } }.sorted { ($0.item.position, $0.key) < ($1.item.position, $1.key) }
    }

    /// The items kept on the device that pass the filter, in the sort's order or the order written; setting the list writes only the items that were added, changed, removed or moved, and leaves the items the filter hides in place.
    public var wrappedValue: [Value] {
        get { Self.stored(under: key).map(\.item.value).filter(shows).sorted(using: descriptors) }
        nonmutating set { write(merged(newValue)) }
    }

    /// The full list with the shown items replaced by the new ones, keeping each hidden item where it was.
    private func merged(_ shown: [Value]) -> [Value] {
        guard filter != nil else { return shown }
        let kept: Set<Value.ID> = Set(shown.map(\.id))
        var remaining: IndexingIterator<[Value]> = shown.makeIterator()
        let merged: [Value] = Self.stored(under: key).map(\.item.value).filter { !shows($0) || kept.contains($0.id) }.compactMap { shows($0) ? remaining.next() : $0 }
        return merged + Array(remaining)
    }

    /// Whether the item passes the filter.
    private func shows(_ item: Value) -> Bool {
        filter.map { (try? $0.evaluate(item)) ?? false } ?? true
    }

    /// Keeps each item as its own record under `key/id`, writing only the items that were added, changed, removed or, without a sort, moved.
    private func write(_ items: [Value]) {
        let stored: [String: Data] = SyncEngine.shared.values(under: key)
        let keys: [String] = items.map { "\(key)/\($0.id)" }
        let old: [Double?] = keys.map { stored[$0].flatMap { DecodedValues.decode(Item.self, from: $0)?.position } }
        let positions: [Double] = descriptors.isEmpty ? SyncEngine.positions(keeping: old) : old.map { $0 ?? 0 }
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var changes: [String: Data?] = Dictionary(uniqueKeysWithValues: Set(stored.keys).subtracting(keys).map { ($0, Data?.none) })
        for (index, item) in items.enumerated() {
            guard let data: Data = try? encoder.encode(Item(position: positions[index], value: item)), data != stored[keys[index]] else { continue }
            changes[keys[index]] = data
        }
        SyncEngine.shared.write(changes)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension ListStorage {

    /// A change to an item that hasn't reached iCloud yet.
    enum Change: Sendable {

        /// An item added on this device.
        case insert(Value)

        /// An item changed on this device.
        case update(Value)

        /// An item removed on this device, as it was last synced.
        case remove(Value)

        /// An item iCloud rejected with the error, which stays on the device and is tried again on every refresh and launch until a save succeeds.
        case failed(Value, CKError)
    }

    /// The item kept in the data, if any.
    private static func item(_ data: Data?) -> Value? {
        data.flatMap { DecodedValues.decode(Item.self, from: $0)?.value }
    }

    /// The changes made on this device that haven't reached iCloud yet, failed ones included, oldest first, kept on the device until they do.
    internal var pending: [Change] {
        let entries: [SyncEntry] = SyncEngine.shared.entries(under: key).values.sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
        return entries.compactMap { entry in
            if case .failure(let error) = entry.status, let item: Value = Self.item(entry.value ?? entry.confirmed) { return .failed(item, error as? CKError ?? CKError(.internalError)) }
            guard entry.isPending else { return nil }
            if let item: Value = Self.item(entry.value) { return entry.confirmed == nil && entry.record == nil ? .insert(item) : .update(item) }
            return Self.item(entry.confirmed).map(Change.remove)
        }
    }

    /// The state of the list's last sync, starting at the last success kept on the device.
    internal var status: SyncStatus {
        SyncEngine.shared.status(key)
    }

    /// When the item was last written, on any device, or `nil` when it isn't kept.
    internal func modified(_ item: Value) -> Date? {
        SyncEngine.shared.entry("\(key)/\(item.id)")?.modified
    }

    /// Fetches the latest items from iCloud and sends every waiting change in the background, reporting the result through `status`.
    internal func refresh() {
        SyncEngine.shared.refresh(key)
    }

    /// Fetches the latest items from iCloud and sends every waiting change, throwing the error a failure gave, such as a lost connection.
    internal func refresh() async throws {
        try await SyncEngine.shared.refresh(key)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ListStorage {

    /// One item as kept in its record, with its position in the list.
    fileprivate struct Item: Codable {

        let position: Double
        let value: Value
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ListStorage.Change: Equatable where Value: Equatable {}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SyncEngine {

    /// Positions for items in their new order that keep the old positions of the most items still in order, so a move or insert rewrites as few records as possible.
    static func positions(keeping old: [Double?]) -> [Double] {
        var links: [Int?] = Array(repeating: nil, count: old.count)
        var tails: [(index: Int, position: Double)] = []
        for (index, position) in old.enumerated() {
            guard let position: Double else { continue }
            let slot: Int = tails.firstIndex { $0.position >= position } ?? tails.count
            links[index] = slot > 0 ? tails[slot - 1].index : nil
            if slot == tails.count { tails.append((index, position)) } else { tails[slot] = (index, position) }
        }
        var kept: [Int: Double] = [:]
        var link: Int? = tails.last?.index
        while let index: Int = link {
            kept[index] = old[index]
            link = links[index]
        }
        var positions: [Double] = []
        for index: Int in old.indices {
            if let position: Double = kept[index] {
                positions.append(position)
                continue
            }
            let following: Double? = old.indices[(index + 1)...].lazy.compactMap { kept[$0] }.first
            switch (positions.last, following) {
            case let (previous?, next?): positions.append((previous + next) / 2)
            case let (previous?, nil): positions.append(previous + 1)
            case let (nil, next?): positions.append(next - 1)
            case (nil, nil): positions.append(0)
            }
        }
        return zip(positions, positions.dropFirst()).allSatisfy(<) ? positions : old.indices.map { Double($0) }
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
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension ListStorage {

    /// The list as bindings to its items, for `ForEach($items) { $item in ... }`, with how its sync is going.
    struct Elements: RandomAccessCollection, Sendable {

        fileprivate let items: [Value]
        fileprivate let storage: ListStorage<Value>

        /// The list's items as they read now.
        fileprivate init(_ storage: ListStorage<Value>) {
            self.items = storage.wrappedValue
            self.storage = storage
        }

        /// The position after the last item.
        public var endIndex: Int {
            items.endIndex
        }

        /// The changes made on this device that haven't reached iCloud yet, failed ones included, oldest first, kept on the device until they do.
        public var pending: [Change] {
            storage.pending
        }

        /// The position of the first item.
        public var startIndex: Int {
            items.startIndex
        }

        /// The state of the list's last sync, starting at the last success kept on the device.
        public var status: SyncStatus {
            storage.status
        }

        /// A binding to the item at the position, which writes through to the list by the item's identity.
        public subscript(position: Int) -> Binding<Value> {
            let item: Value = items[position]
            let storage: ListStorage<Value> = storage
            return Binding(get: { storage.wrappedValue.first { $0.id == item.id } ?? item }, set: { changed in
                var items: [Value] = storage.wrappedValue
                guard let index: Int = items.firstIndex(where: { $0.id == item.id }) else { return }
                items[index] = changed
                storage.wrappedValue = items
            })
        }

        /// When the item was last written, on any device, or `nil` when it isn't kept.
        public func modified(_ item: Value) -> Date? {
            storage.modified(item)
        }

        /// Fetches the latest items from iCloud and sends every waiting change in the background, reporting the result through `status`.
        public func refresh() {
            storage.refresh()
        }

        /// Fetches the latest items from iCloud and sends every waiting change, throwing the error a failure gave, such as a lost connection.
        public func refresh() async throws {
            try await storage.refresh()
        }
    }

    /// The list as bindings to its items, with its sync status, pending changes, and refresh.
    var projectedValue: Elements {
        Elements(self)
    }
}
#endif
