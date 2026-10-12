// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/PublicStorage.swift
// dependencies: []
// permissions: [com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services]

// Setup in Xcode:
// 1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
// 2. Under iCloud, check CloudKit and select or create the container named iCloud. followed by the bundle identifier, which PublicStorage uses.
// 3. Open the CloudKit Console at https://icloud.developer.apple.com, choose that container, then the Development environment.
// 4. Under Schema, add a record type named PublicStorage with the fields key (String), modified (Date/Time) and value (Bytes).
// 5. Under Indexes, add a Queryable index on PublicStorage's key field. Every read fails until it exists.
// 6. Leave the Security Roles at their defaults, which let anyone read and only each record's creator change it.
// 7. Run on a device or simulator signed in to iCloud. Reading works signed out, but writing needs an account.
// 8. Before TestFlight or the App Store, click Deploy Schema Changes to copy the schema to Production.

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import CloudKit
import Foundation
import Observation
import os
import Security

/// Reads every user's entry for a key in the app's public iCloud database through an optional filter, oldest first or in the order the sort gives.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct PublicStorage<Value: Codable & Sendable>: Sendable {

    private let filter: Predicate<Value>?
    private let key: String
    private let sort: [SortDescriptor<Value>]

    /// Creates storage for the key, shared by every user of the app, whose entries read through the filter, oldest first or sorted by the descriptors.
    public init(_ key: String, filter: Predicate<Value>? = nil, sort descriptors: [SortDescriptor<Value>] = []) {
        self.filter = filter
        self.key = key
        self.sort = descriptors
    }

    /// Creates storage for the key, shared by every user of the app, whose entries read through the filter, sorted by the key path.
    public init<C: Comparable>(_ key: String, filter: Predicate<Value>? = nil, sort keyPath: KeyPath<Value, C> & Sendable, order: SortOrder = .forward) {
        self.init(key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// Creates storage for the key, shared by every user of the app, whose entries read through the filter, sorted by the optional key path.
    public init<C: Comparable>(_ key: String, filter: Predicate<Value>? = nil, sort keyPath: KeyPath<Value, C?> & Sendable, order: SortOrder = .forward) {
        self.init(key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// Every user's entry that passes the filter, oldest first or in the order the sort gives, refreshed from iCloud when read at most once a minute.
    public var wrappedValue: [Value] {
        let entries: [Value] = PublicStore.shared.entries(key).compactMap { DecodedValues.decode(Value.self, from: $0) }.filter { entry in filter.map { (try? $0.evaluate(entry)) ?? false } ?? true }
        return sort.isEmpty ? entries : entries.sorted(using: sort)
    }

    /// The current user's entry, kept on the device and sent to iCloud; setting `nil` removes it.
    var entry: Value? {
        get { PublicStore.shared.entry(key).flatMap { DecodedValues.decode(Value.self, from: $0) } }
        nonmutating set { PublicStore.shared.write(newValue.flatMap { try? JSONEncoder().encode($0) }, key) }
    }
}

/// Keeps each key's entries in a file on the device and syncs them through the public iCloud database, one record per user, where the newest write wins.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class PublicStore: Observable, Sendable {

    private let entries: OSAllocatedUnfairLock<[String: PublicEntry]>
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let syncs: OSAllocatedUnfairLock<[String: (requested: Date, task: Task<Void, Never>)]> = OSAllocatedUnfairLock(initialState: [:])

    /// Restores the entries kept on the device.
    private init() {
        let stored: [String: PublicEntry] = Self.file.read() ?? [:]
        self.entries = OSAllocatedUnfairLock(initialState: stored)
    }

    /// The store every public value shares.
    static let shared: PublicStore = PublicStore()

    /// The file the entries are kept in.
    private static let file: DeviceFile<[String: PublicEntry]> = DeviceFile("PublicStorage")

    /// The record type every entry is saved as.
    private static let recordType: CKRecord.RecordType = "PublicStorage"

    /// The length of the period and iCloud user record name that follow the key in each record's name.
    private static let userSuffix: Int = 34

    /// The CloudKit limit a record named after the key, with the user suffix after it, and holding the data would break, or `nil` when it fits: an ASCII name that leaves room for the suffix in 255 characters and doesn't start with an underscore, and data under 1 MB.
    static func recordViolation(named key: String, holding data: Data?) -> String? {
        if key.hasPrefix("_") || !key.allSatisfy(\.isASCII) { return "The key \"\(key)\" must be ASCII and not start with an underscore to name a CloudKit record." }
        if key.utf8.count + userSuffix > 255 { return "The key \"\(key)\" is over the \(255 - userSuffix) characters a PublicStorage record name has room for." }
        if let data: Data, data.count >= 1_000_000 { return "The value for \"\(key)\" is \(data.count) bytes, over the 1 MB a CloudKit record holds." }
        return nil
    }

    /// Whether a write waiting on the device should replace the server's value, which only a strictly newer write does.
    private static func prefersLocal(written local: Date?, over server: Date?) -> Bool {
        guard let local: Date else { return false }
        return local > server ?? .distantPast
    }

    /// The name of the user's record for the key, so each user has exactly one.
    private static func recordName(_ key: String, _ user: String) -> String {
        "\(key).\(user)"
    }

    /// A placeholder property that observers track in place of the entries.
    private var revision: Void { () }

    /// Every user's entry for the key, oldest first, syncing when the last sync is over a minute old.
    func entries(_ key: String) -> [Data] {
        registrar.access(self, keyPath: \.revision)
        sync(key, ifOlderThan: 60)
        guard let entry: PublicEntry = entries.withLock({ $0[key] }) else { return [] }
        let mine: [PublicValue] = entry.mine.map { [PublicValue(modified: entry.modified ?? .now, value: $0)] } ?? []
        return (mine + entry.others).sorted { $0.modified < $1.modified }.map(\.value)
    }

    /// The current user's entry for the key, syncing when the last sync is over a minute old.
    func entry(_ key: String) -> Data? {
        registrar.access(self, keyPath: \.revision)
        sync(key, ifOlderThan: 60)
        return entries.withLock { $0[key]?.mine }
    }

    /// Keeps the current user's entry on the device and sends it to iCloud, stopping debug builds on a value CloudKit can't hold.
    func write(_ data: Data?, _ key: String) {
        assert(Self.recordViolation(named: key, holding: data) == nil, Self.recordViolation(named: key, holding: data) ?? "")
        let date: Date = .now
        update(key) { entry in
            entry.isPending = true
            entry.mine = data
            entry.modified = date
        }
        sync(key)
    }

    /// Fetches every record for the key, keeping the others' entries and adopting the user's own unless a newer write waits to replace it.
    private func fetch(_ key: String, as user: String?, from database: CKDatabase) async throws {
        let keys: [CKRecord.FieldKey] = ["modified", "value"]
        var page: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?) = try await database.records(matching: CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "key == %@", key)), desiredKeys: keys)
        var records: [CKRecord] = page.matchResults.compactMap { try? $0.1.get() }
        while let cursor: CKQueryOperation.Cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor, desiredKeys: keys)
            records += page.matchResults.compactMap { try? $0.1.get() }
        }
        let name: String? = user.map { Self.recordName(key, $0) }
        let others: [PublicValue] = records.filter { $0.recordID.recordName != name }.compactMap { record in
            guard let value: Data = record["value"] as? Data else { return nil }
            return PublicValue(modified: record["modified"] as? Date ?? record.modificationDate ?? .distantPast, value: value)
        }
        update(key) { $0.others = others }
        guard user != nil else { return }
        receive(records.first { $0.recordID.recordName == name }, key)
    }

    /// Adopts the user's own record from iCloud, or its absence, unless a newer write on the device waits to replace it.
    private func receive(_ record: CKRecord?, _ key: String) {
        let modified: Date? = record?["modified"] as? Date
        let value: Data? = record?["value"] as? Data
        update(key) { entry in
            guard !entry.isPending || !Self.prefersLocal(written: entry.modified, over: modified) else { return }
            entry.isPending = false
            entry.mine = value
            entry.modified = modified
        }
    }

    /// Saves the entry into the record, which keeps a removed entry as a record without a value so its time still decides conflicts.
    private func save(_ record: CKRecord, _ entry: PublicEntry, _ key: String, _ database: CKDatabase) async throws {
        record["key"] = key
        record["modified"] = entry.modified
        record["value"] = entry.mine
        do {
            _ = try await database.modifyRecords(saving: [record], deleting: []).saveResults[record.recordID]?.get()
            update(key) { if $0.modified == entry.modified { $0.isPending = false } }
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let server: CKRecord = error.serverRecord else { throw error }
            guard Self.prefersLocal(written: entry.modified, over: server["modified"] as? Date) else { return receive(server, key) }
            try await save(server, entry, key, database)
        }
    }

    /// Sends the user's waiting write, saving over a conflicting record only when the write is newer.
    private func send(_ key: String, as user: String, to database: CKDatabase) async throws {
        guard let entry: PublicEntry = entries.withLock({ $0[key] }), entry.isPending else { return }
        try await save(CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: Self.recordName(key, user))), entry, key, database)
    }

    /// Sends the key's waiting write and fetches every entry after any sync already under way, unless one began within the age.
    private func sync(_ key: String, ifOlderThan age: TimeInterval = 0) {
        guard hasCloudKitEntitlement else { return }
        syncs.withLock { syncs in
            if let last: Date = syncs[key]?.requested, -last.timeIntervalSinceNow < age { return }
            let previous: Task<Void, Never>? = syncs[key]?.task
            syncs[key] = (.now, Task { [self] in
                await previous?.value
                let container: CKContainer = CKContainer.default()
                let user: String? = try? await container.userRecordID().recordName
                if let user {
                    update(key) { entry in
                        if let owner: String = entry.owner, owner != user { entry = PublicEntry(others: entry.others) }
                        entry.owner = user
                    }
                    try? await send(key, as: user, to: container.publicCloudDatabase)
                }
                try? await fetch(key, as: user, from: container.publicCloudDatabase)
            })
        }
    }

    /// Changes the entries, keeps them on the device, and tells observers.
    private func update(_ key: String, _ change: @Sendable (inout PublicEntry) -> Void) {
        registrar.withMutation(of: self, keyPath: \.revision) {
            entries.withLock { entries in
                change(&entries[key, default: PublicEntry()])
                Self.file.write(entries)
            }
        }
    }
}

/// A value kept as JSON in the named file in the app's Application Support folder, written in the background so a change never waits on the disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate final class DeviceFile<Contents: Codable & Sendable>: Sendable {

    private let pending: OSAllocatedUnfairLock<Contents?> = OSAllocatedUnfairLock(initialState: nil)
    private let queue: DispatchQueue
    private let url: URL

    /// Creates the file with the name, in a Composition folder kept apart for each app.
    init(_ name: String) {
        self.queue = DispatchQueue(label: "Composition.\(name)", qos: .utility)
        self.url = URL.applicationSupportDirectory.appending(components: Bundle.main.bundleIdentifier ?? "Composition", "Composition", "\(name).json")
    }

    /// The contents last written, once any write still waiting finishes, or `nil` when nothing was written.
    func read() -> Contents? {
        queue.sync {}
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    }

    /// Writes the contents in the background, where newer contents replace any still waiting to be written.
    func write(_ contents: Contents) {
        let isIdle: Bool = pending.withLock { pending in
            defer { pending = contents }
            return pending == nil
        }
        guard isIdle else { return }
        queue.async { [self] in
            guard let latest: Contents = pending.withLock({ pending in defer { pending = nil }; return pending }), let data: Data = try? JSONEncoder().encode(latest) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
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

/// Whether the app can use CloudKit, which macOS only grants to apps signed with the iCloud entitlement.
fileprivate let hasCloudKitEntitlement: Bool = {
    #if os(macOS)
    guard let task: SecTask = SecTaskCreateFromSelf(nil) else { return false }
    return SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil) != nil
    #else
    return true
    #endif
}()

/// A key's entries as kept on the device: the current user's own, with the time it was written, and everyone else's.
fileprivate struct PublicEntry: Codable, Sendable {

    var isPending: Bool = false
    var mine: Data?
    var modified: Date?
    var others: [PublicValue] = []
    var owner: String?
}

/// A user's entry, with the time it was written.
fileprivate struct PublicValue: Codable, Sendable {

    let modified: Date
    let value: Data
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension PublicStorage {

    /// A binding to the current user's entry, where setting `nil` removes it.
    var projectedValue: Binding<Value?> {
        Binding(get: { entry }, set: { entry = $0 })
    }
}
#endif
