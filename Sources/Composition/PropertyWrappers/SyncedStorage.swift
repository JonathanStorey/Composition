// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorage.swift
// dependencies: []
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services]

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

/// The state of a value's last sync, shaped like `Result`, with the date of the last success.
public enum SyncStatus: Codable, Hashable, Sendable {

    /// Not synced since launch, and no earlier success is known.
    case unknown

    /// Waiting on a sync that is under way.
    case syncing

    /// Synced successfully at the date.
    case success(Date)

    /// The last sync failed for the reason.
    case failure(SyncError)
}

/// Why a sync with iCloud, or a check of the internet connection, failed.
public enum SyncError: Error, Codable, Hashable, Sendable {

    /// No iCloud account is signed in, or iCloud is turned off for the app.
    case noAccount

    /// The device can't reach the server right now, and a sync will retry.
    case offline

    /// The user's iCloud storage is full.
    case quotaExceeded

    /// iCloud refused the sync, such as when the app lacks the iCloud entitlement.
    case unavailable
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import CloudKit
import Observation
import os
import Security

/// Reads and writes a value like `AppStorage`, kept on the device and synced through the user's private iCloud database.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
public struct SyncedStorage<Value: Codable & Sendable>: Sendable {

    /// Which value wins when two devices write before either has synced.
    public let conflict: Conflict
    /// The value returned when nothing is stored.
    public let defaultValue: Value
    /// The key the value is stored under.
    public let key: String

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String, _ conflict: Conflict = .latest) {
        self.conflict = conflict
        self.defaultValue = wrappedValue
        self.key = key
        SyncEngine.shared.register(key, keepsFirst: conflict == .first)
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String, _ conflict: Conflict = .latest) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key, conflict)
    }

    /// The value kept on the device, or the default value when nothing is stored; setting `nil` removes it.
    public var wrappedValue: Value {
        get {
            guard let data: Data = SyncEngine.shared.value(key), let value: Value = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            let data: Data? = (try? JSONEncoder().encode(newValue)).flatMap { $0 == Data("null".utf8) ? nil : $0 }
            SyncEngine.shared.write(data, key)
        }
    }

    /// The last time the value made a round trip to iCloud, kept on the device.
    var lastSynced: Date? {
        SyncEngine.shared.lastSynced(key)
    }

    /// The status of the value's last sync.
    var status: SyncStatus {
        SyncEngine.shared.status(key)
    }

    /// The value as of its last round trip to iCloud, or the default value before the first.
    var syncedValue: Value {
        guard let data: Data = SyncEngine.shared.syncedValue(key), let value: Value = try? JSONDecoder().decode(Value.self, from: data) else { return defaultValue }
        return value
    }

    /// Fetches the latest values from iCloud in the background, moving the status to syncing and then to success or failure.
    func refresh() {
        SyncEngine.shared.refresh(key)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension SyncedStorage {

    /// Which value wins when two devices write before either has synced.
    enum Conflict: Hashable, Sendable {

        /// The newest write wins, by the time each device wrote it, so an older write never replaces a newer one.
        case latest

        /// The value already on the server wins, and the device adopts it.
        case first
    }
}

/// Keeps every synced value on the device and syncs them through the private iCloud database, tracking each key's status.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class SyncEngine: CKSyncEngineDelegate, Observable, Sendable {

    private let engine: OSAllocatedUnfairLock<CKSyncEngine?> = OSAllocatedUnfairLock(uncheckedState: nil)
    private let entries: OSAllocatedUnfairLock<[String: SyncEntry]>
    private let registrar: ObservationRegistrar = ObservationRegistrar()

    /// Restores the values kept on the device, each starting at its last success, or unknown when it never synced.
    private init() {
        let stored: [String: SyncEntry] = UserDefaults.standard.data(forKey: Self.entriesKey).flatMap { try? JSONDecoder().decode([String: SyncEntry].self, from: $0) } ?? [:]
        self.entries = OSAllocatedUnfairLock(initialState: stored.mapValues { entry in
            var restored: SyncEntry = entry
            restored.status = entry.synced.map(SyncStatus.success) ?? .unknown
            return restored
        })
    }

    /// The engine every synced value shares.
    static let shared: SyncEngine = SyncEngine()

    /// The user defaults key the values are kept under.
    private static let entriesKey: String = "Composition.SyncedStorage.entries"

    /// The user defaults key the engine's state is kept under.
    private static let serializationKey: String = "Composition.SyncedStorage.engine"

    /// Whether a write waiting on the device should replace the server's value, which only a strictly newer write does, and never when the key keeps the first value.
    static func prefersLocal(written local: Date?, over server: Date?, keepsFirst: Bool) -> Bool {
        guard !keepsFirst, let local: Date else { return false }
        return local > server ?? .distantPast
    }

    /// The reason a CloudKit error gives for a failed sync.
    private static func reason(for error: any Error) -> SyncError {
        switch (error as? CKError)?.code {
        case .notAuthenticated?: .noAccount
        case .networkFailure?, .networkUnavailable?, .requestRateLimited?, .serviceUnavailable?, .zoneBusy?: .offline
        case .quotaExceeded?: .quotaExceeded
        default: .unavailable
        }
    }

    /// Rebuilds a record from its archived server fields.
    private static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let unarchiver: NSKeyedUnarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }

    /// Archives the record's server fields, which let the next save update it instead of conflicting.
    private static func systemFields(of record: CKRecord) -> Data {
        let archiver: NSKeyedArchiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// A placeholder property that observers track in place of the values and statuses.
    private var revision: Void { () }

    /// The zone in the private database that holds every synced value.
    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "Composition")
    }

    /// Handles the engine's events: saved state, account changes, values fetched from iCloud, and the results of sending.
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            UserDefaults.standard.set(try? JSONEncoder().encode(update.stateSerialization), forKey: Self.serializationKey)
        case .accountChange(let change):
            if case .signIn = change.changeType { return }
            updateAll { entry in entry = SyncEntry(keepsFirst: entry.keepsFirst) }
        case .fetchedRecordZoneChanges(let changes):
            changes.modifications.forEach { receive($0.record) }
            changes.deletions.forEach { deletion in update(deletion.recordID.recordName) { $0.confirmed = nil; $0.record = nil; $0.value = nil } }
        case .sentRecordZoneChanges(let sent):
            sent.savedRecords.forEach(confirm)
            sent.deletedRecordIDs.forEach(confirmDeletion)
            sent.failedRecordSaves.forEach { resolve($0.record, $0.error, syncEngine) }
            sent.failedRecordDeletes.forEach { id, error in error.code == .unknownItem ? confirmDeletion(id) : fail(id.recordName, error) }
        default:
            break
        }
    }

    /// The last time the key's value made a round trip to iCloud.
    func lastSynced(_ key: String) -> Date? {
        registrar.access(self, keyPath: \.revision)
        return entries.withLock { $0[key]?.synced }
    }

    /// Builds the next batch of records to send from the values written on the device.
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes: [CKSyncEngine.PendingRecordZoneChange] = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { [self] id in record(for: id) }
    }

    /// Fetches the latest values from iCloud and sends any waiting writes, recording the result as the key's status.
    func refresh(_ key: String) {
        guard let engine: CKSyncEngine = start() else { return update(key) { $0.status = .failure(.unavailable) } }
        update(key) { $0.status = .syncing }
        Task {
            do {
                try await engine.fetchChanges()
                try await engine.sendChanges()
                let date: Date = .now
                update(key) { entry in
                    guard entry.status == .syncing else { return }
                    entry.status = .success(date)
                    entry.synced = date
                }
            } catch {
                fail(key, error)
            }
        }
    }

    /// Records whether the key's conflicts keep the value already on the server.
    func register(_ key: String, keepsFirst: Bool) {
        entries.withLock { $0[key, default: SyncEntry()].keepsFirst = keepsFirst }
    }

    /// The status of the key's last sync.
    func status(_ key: String) -> SyncStatus {
        registrar.access(self, keyPath: \.revision)
        return entries.withLock { $0[key]?.status ?? .unknown }
    }

    /// The key's value as of its last round trip to iCloud.
    func syncedValue(_ key: String) -> Data? {
        registrar.access(self, keyPath: \.revision)
        start()
        return entries.withLock { $0[key]?.confirmed }
    }

    /// The key's value as kept on the device, starting the engine so iCloud's values arrive.
    func value(_ key: String) -> Data? {
        registrar.access(self, keyPath: \.revision)
        start()
        return entries.withLock { $0[key]?.value }
    }

    /// Keeps the value on the device and queues it for iCloud, leaving the status to the sync's result or the next refresh.
    func write(_ data: Data?, _ key: String) {
        let date: Date = .now
        guard let engine: CKSyncEngine = start() else { return update(key) { $0.modified = date; $0.value = data } }
        update(key) { entry in
            entry.isPending = true
            entry.modified = date
            entry.value = data
        }
        let id: CKRecord.ID = CKRecord.ID(recordName: key, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [data == nil ? .deleteRecord(id) : .saveRecord(id)])
    }

    /// Marks a saved record's key as synced at the server's time.
    private func confirm(_ record: CKRecord) {
        let fields: Data = Self.systemFields(of: record)
        let value: Data? = record["value"] as? Data
        let date: Date = record.modificationDate ?? .now
        update(record.recordID.recordName) { entry in
            entry.confirmed = value
            entry.isPending = false
            entry.record = fields
            entry.status = .success(date)
            entry.synced = date
        }
    }

    /// Marks a removed record's key as synced now.
    private func confirmDeletion(_ id: CKRecord.ID) {
        let date: Date = .now
        update(id.recordName) { entry in
            entry.confirmed = nil
            entry.isPending = false
            entry.record = nil
            entry.status = .success(date)
            entry.synced = date
        }
    }

    /// Records the reason a CloudKit error gives as the key's status.
    private func fail(_ key: String, _ error: any Error) {
        let reason: SyncError = Self.reason(for: error)
        update(key) { $0.status = .failure(reason) }
    }

    /// Takes in a record from iCloud, adopting its value unless a newer write on the device is waiting to replace it.
    private func receive(_ record: CKRecord) {
        let fields: Data = Self.systemFields(of: record)
        let modified: Date? = record["modified"] as? Date
        let value: Data? = record["value"] as? Data
        let date: Date = record.modificationDate ?? .now
        update(record.recordID.recordName) { entry in
            entry.confirmed = value
            entry.record = fields
            guard !entry.isPending || !Self.prefersLocal(written: entry.modified, over: modified, keepsFirst: entry.keepsFirst) else { return }
            entry.isPending = false
            entry.modified = modified
            entry.status = .success(date)
            entry.synced = date
            entry.value = value
        }
    }

    /// Builds the record to send for the key with the time it was written, or `nil`, which drops the change, when nothing waits to be sent.
    private func record(for id: CKRecord.ID) -> CKRecord? {
        guard let entry: SyncEntry = entries.withLock({ $0[id.recordName] }), entry.isPending, let value: Data = entry.value else { return nil }
        let record: CKRecord = entry.record.flatMap(Self.record(fromSystemFields:)) ?? CKRecord(recordType: "SyncedStorage", recordID: id)
        record["modified"] = entry.modified
        record["value"] = value
        return record
    }

    /// Settles a failed save: a conflict by keeping the newer write, a missing zone by creating it, and anything else as a failure.
    private func resolve(_ record: CKRecord, _ error: CKError, _ engine: CKSyncEngine) {
        let key: String = record.recordID.recordName
        switch error.code {
        case .serverRecordChanged:
            guard let server: CKRecord = error.serverRecord else { break }
            receive(server)
            if entries.withLock({ $0[key]?.isPending ?? false }) { engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)]) }
            return
        case .zoneNotFound:
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            return
        default:
            break
        }
        fail(key, error)
    }

    /// Changes the entries, keeps them on the device, and tells observers.
    private func save(_ change: @Sendable (inout [String: SyncEntry]) -> Void) {
        let data: Data? = registrar.withMutation(of: self, keyPath: \.revision) {
            entries.withLock { entries in
                change(&entries)
                return try? JSONEncoder().encode(entries)
            }
        }
        UserDefaults.standard.set(data, forKey: Self.entriesKey)
    }

    /// Creates the engine on first use, queuing every write an earlier launch left unsent, or returns `nil` when the app can't use CloudKit.
    @discardableResult private func start() -> CKSyncEngine? {
        guard hasCloudKitEntitlement else { return nil }
        return engine.withLockUnchecked { stored in
            if let stored { return stored }
            let serialization: CKSyncEngine.State.Serialization? = UserDefaults.standard.data(forKey: Self.serializationKey).flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
            let created: CKSyncEngine = CKSyncEngine(CKSyncEngine.Configuration(database: CKContainer.default().privateCloudDatabase, stateSerialization: serialization, delegate: self))
            let unsent: [CKSyncEngine.PendingRecordZoneChange] = entries.withLock { $0.filter(\.value.isPending) }.map { key, entry in entry.value == nil ? .deleteRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) : .saveRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) }
            if serialization == nil { created.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))]) }
            created.state.add(pendingRecordZoneChanges: unsent)
            stored = created
            return created
        }
    }

    /// Changes the key's entry, keeps every entry on the device, and tells observers.
    private func update(_ key: String, _ change: @Sendable (inout SyncEntry) -> Void) {
        save { change(&$0[key, default: SyncEntry()]) }
    }

    /// Changes every entry, keeps them on the device, and tells observers.
    private func updateAll(_ change: @Sendable (inout SyncEntry) -> Void) {
        save { entries in
            entries = entries.mapValues { entry in
                var changed: SyncEntry = entry
                change(&changed)
                return changed
            }
        }
    }
}

/// A key's value as kept on the device, with its sync status and the archived server fields of its record.
fileprivate struct SyncEntry: Codable, Sendable {

    var confirmed: Data?
    var isPending: Bool = false
    var keepsFirst: Bool = false
    var modified: Date?
    var record: Data?
    var status: SyncStatus = .unknown
    var synced: Date?
    var value: Data?
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
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension SyncedStorage {

    /// A binding to the value, for controls such as `TextField` and `Toggle`.
    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
#endif
