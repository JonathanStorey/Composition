// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/PublicStorage.swift
// dependencies: [PropertyWrappers/SyncedStorage.swift]
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

/// Reads every user's entry for a key in the app's public iCloud database, oldest first.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct PublicStorage<Value: Codable & Sendable>: Sendable {

    private let key: String

    /// Creates storage for the key, shared by every user of the app.
    public init(_ key: String) {
        self.key = key
    }

    /// Every user's entry, oldest first, refreshed from iCloud when read at most once a minute.
    public var wrappedValue: [Value] {
        PublicStore.shared.entries(key).compactMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }

    /// The current user's entry, kept on the device and sent to iCloud; setting `nil` removes it.
    var entry: Value? {
        get { PublicStore.shared.entry(key).flatMap { try? JSONDecoder().decode(Value.self, from: $0) } }
        nonmutating set { PublicStore.shared.write(newValue.flatMap { try? JSONEncoder().encode($0) }, key) }
    }
}

/// Keeps each key's entries on the device and syncs them through the public iCloud database, one record per user, where the newest write wins.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class PublicStore: Observable, Sendable {

    private let entries: OSAllocatedUnfairLock<[String: PublicEntry]>
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let syncs: OSAllocatedUnfairLock<[String: (requested: Date, task: Task<Void, Never>)]> = OSAllocatedUnfairLock(initialState: [:])

    /// Restores the entries kept on the device.
    private init() {
        let stored: [String: PublicEntry] = UserDefaults.standard.data(forKey: Self.entriesKey).flatMap { try? JSONDecoder().decode([String: PublicEntry].self, from: $0) } ?? [:]
        self.entries = OSAllocatedUnfairLock(initialState: stored)
    }

    /// The store every public value shares.
    static let shared: PublicStore = PublicStore()

    /// The user defaults key the entries are kept under.
    private static let entriesKey: String = "Composition.PublicStorage.entries"

    /// The record type every entry is saved as.
    private static let recordType: CKRecord.RecordType = "PublicStorage"

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

    /// Keeps the current user's entry on the device and sends it to iCloud.
    func write(_ data: Data?, _ key: String) {
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
            guard !entry.isPending || !SyncEngine.prefersLocal(written: entry.modified, over: modified) else { return }
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
            guard SyncEngine.prefersLocal(written: entry.modified, over: server["modified"] as? Date) else { return receive(server, key) }
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
        let data: Data? = registrar.withMutation(of: self, keyPath: \.revision) {
            entries.withLock { entries in
                change(&entries[key, default: PublicEntry()])
                return try? JSONEncoder().encode(entries)
            }
        }
        UserDefaults.standard.set(data, forKey: Self.entriesKey)
    }
}

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
