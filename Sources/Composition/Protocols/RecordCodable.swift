// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordCodable.swift
// dependencies: []
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, UIBackgroundModes]

// Setup in Xcode for RecordContext:
// 1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
// 2. Under iCloud, check CloudKit and select or create the container, which RecordContext uses when its identifier is passed and the default container otherwise.
// 3. Click + Capability again and add Push Notifications, so other devices' changes arrive without waiting for the next launch.
// 4. On iOS, also add Background Modes and check Remote notifications.
// 5. Run on a device or simulator signed in to iCloud. Records stay on the device while signed out and sync once an account is available.
// 6. Before TestFlight or the App Store, open the CloudKit Console at https://icloud.developer.apple.com, choose the container, and click Deploy Schema Changes to copy the record types to Production.

// MARK: - CloudKit + Foundation

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation

/// A type that reads and writes itself as the fields of a CloudKit record, like `Codable`, leaving the record's type, name and zone to whoever creates it.
public protocol RecordCodable {

    /// Creates the value from the record's fields, like `Decodable`'s `init(from:)`, throwing when they don't hold one.
    init(from record: CKRecord) throws

    /// Writes the value's fields into the record, like `Encodable`'s `encode(to:)`, leaving its name, zone and server fields as they are.
    func encode(to record: CKRecord) throws
}

public extension RecordCodable where Self: Codable {

    /// Creates the value from the JSON kept in the record's `value` field.
    init(from record: CKRecord) throws {
        guard let data: Data = record["value"] as? Data else { throw DecodingError.valueNotFound(Self.self, DecodingError.Context(codingPath: [], debugDescription: "The record has no value field.")) }
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    /// Writes the value as JSON into the record's `value` field.
    func encode(to record: CKRecord) throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        record["value"] = try encoder.encode(self)
    }
}

/// A change saved on the device that hasn't reached iCloud yet, holding the record, or the value it keeps.
public enum PendingChange<V> {

    /// A record iCloud doesn't have yet.
    case insert(V)

    /// A record iCloud has, changed on this device.
    case update(V)

    /// A record removed on this device.
    case delete(CKRecord.ID)

    /// A change iCloud rejected with the error, holding the value unless the change removed it, tried again on every refresh and launch until it succeeds.
    case failed(CKRecord.ID, V?, CKError)
}

/// A description of the values to fetch from a record context, like SwiftData's `FetchDescriptor`.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct RecordDescriptor<R: RecordCodable> {

    /// The largest number of values to fetch, or `nil` for all of them.
    public var fetchLimit: Int?

    /// The condition a value meets to be fetched, or `nil` for every value.
    public var predicate: Predicate<R>?

    /// The order of the fetched values, which follows their record names when empty.
    public var sortBy: [SortDescriptor<R>]

    /// The zone that holds the values.
    public var zone: String

    /// Creates a description of the values in the zone that meet the predicate, in the order of the sort descriptors.
    public init(predicate: Predicate<R>? = nil, sortBy: [SortDescriptor<R>] = [], zone: String = "Composition") {
        self.predicate = predicate
        self.sortBy = sortBy
        self.zone = zone
    }
}

/// Two versions of a record that changed on this device and on the server before either saw the other, where the device's version was kept and sent.
public struct RecordConflict: Identifiable {

    /// The identifier of the record both versions belong to.
    public let id: CKRecord.ID

    /// The version written on this device, which replaced the server's.
    public let local: CKRecord

    /// The version on the server when the device's arrived, which another device wrote.
    public let server: CKRecord
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Observation
import os
import Security

/// Reads and writes `RecordCodable` values like SwiftData's `ModelContext`, at once from a cache on the device, and syncs them through the private iCloud database with a `CKSyncEngine`.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public final class RecordContext: CKSyncEngineDelegate, Observable, Sendable {

    private let identifier: String?
    private let registrar: ObservationRegistrar = ObservationRegistrar()
    private let store: OSAllocatedUnfairLock<Store>
    private let writer: Writer = Writer()

    /// Creates a context for the private database of the iCloud container with the identifier, or of the app's default container, keeping its cache in the app's own folder.
    public convenience init(_ identifier: String? = nil) {
        self.init(identifier, folder: URL.applicationSupportDirectory.appending(components: Bundle.main.bundleIdentifier ?? "Composition", "Composition", "RecordContext", identifier ?? "default", directoryHint: .isDirectory))
    }

    /// Creates a context that keeps its cache in the folder.
    init(_ identifier: String?, folder: URL) {
        self.identifier = identifier
        self.store = OSAllocatedUnfairLock(uncheckedState: Store(folder: folder))
    }

    /// The name of the record that keeps the value, its type followed by its identifier, as in `Note.42`.
    static func recordName<R: Identifiable>(of value: R) -> String {
        "\(recordType(of: R.self)).\(value.id)"
    }

    /// The record type that keeps values of the type, its name without its module, parents or generic arguments.
    static func recordType(of type: Any.Type) -> String {
        let name: Substring = String(reflecting: type).prefix { $0 != "<" }
        return String(name.split(separator: ".").last ?? name)
    }

    /// The record archived with its fields and server fields.
    fileprivate static func archive(_ record: CKRecord) -> Data {
        let archiver: NSKeyedArchiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encode(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// The record kept in the archive, with its fields and server fields.
    fileprivate static func record(from archive: Data) -> CKRecord? {
        guard let unarchiver: NSKeyedUnarchiver = try? NSKeyedUnarchiver(forReadingFrom: archive) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }

    /// A Boolean value indicating whether the records hold equal values in every field.
    private static func fieldsMatch(_ first: CKRecord, _ second: CKRecord) -> Bool {
        Set(first.allKeys()).union(second.allKeys()).allSatisfy { (first.object(forKey: $0) as? NSObject) == (second.object(forKey: $0) as? NSObject) }
    }

    /// A copy of the base record, keeping its server fields, holding exactly the fields of the values record.
    private static func rebased(_ values: CKRecord, onto base: CKRecord) -> CKRecord {
        let record: CKRecord = base.copy() as? CKRecord ?? base
        for key: String in Set(base.allKeys()).union(values.allKeys()) {
            record.setObject(values.object(forKey: key), forKey: key)
        }
        return record
    }

    /// The status of the iCloud account, which is `couldNotDetermine` until the context first syncs.
    public var account: CKAccountStatus {
        registrar.access(self, keyPath: \.account)
        return store.withLockUnchecked { $0.account }
    }

    /// A Boolean value indicating whether the context saves its changes on its own shortly after they're made, which is on by default.
    public var autosaveEnabled: Bool {
        get { store.withLockUnchecked { $0.autosaveEnabled } }
        set { store.withLockUnchecked { $0.autosaveEnabled = newValue } }
    }

    /// The identifiers of the records changed since the last save, which already existed.
    public var changedRecords: [CKRecord.ID] {
        registrar.access(self, keyPath: \.changes)
        return store.withLockUnchecked { store in
            let staged: [RecordKey: Change] = store.staged
            return staged.filter { key, change in change.isSave && store.withTable(key.table) { $0.records[key.name] != nil } }.keys.map(\.id)
        }
    }

    /// The versions of records that another device changed while this one did, kept until resolved.
    public var conflicts: [RecordConflict] {
        registrar.access(self, keyPath: \.conflicts)
        return store.withLockUnchecked { $0.conflicts.values.sorted { $0.id.recordName < $1.id.recordName } }
    }

    /// The iCloud container whose private database the context syncs with.
    public var container: CKContainer {
        identifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
    }

    /// The identifiers of the records deleted since the last save.
    public var deletedRecords: [CKRecord.ID] {
        registrar.access(self, keyPath: \.changes)
        return store.withLockUnchecked { $0.staged.filter { !$0.value.isSave }.keys.map(\.id) }
    }

    /// A Boolean value indicating whether the context has changes it hasn't saved.
    public var hasChanges: Bool {
        registrar.access(self, keyPath: \.changes)
        return store.withLockUnchecked { !$0.staged.isEmpty }
    }

    /// The identifiers of the records inserted since the last save, which didn't exist before.
    public var insertedRecords: [CKRecord.ID] {
        registrar.access(self, keyPath: \.changes)
        return store.withLockUnchecked { store in
            let staged: [RecordKey: Change] = store.staged
            return staged.filter { key, change in change.isSave && store.withTable(key.table) { $0.records[key.name] == nil } }.keys.map(\.id)
        }
    }

    /// A Boolean value indicating whether the context is fetching changes from iCloud.
    public var isFetching: Bool {
        registrar.access(self, keyPath: \.isFetching)
        return store.withLockUnchecked { $0.fetches > 0 }
    }

    /// A Boolean value indicating whether the context is sending changes to iCloud.
    public var isSending: Bool {
        registrar.access(self, keyPath: \.isSending)
        return store.withLockUnchecked { $0.sends > 0 }
    }

    /// The last time a fetch from or send to iCloud finished, kept on the device.
    public var lastSync: Date? {
        registrar.access(self, keyPath: \.lastSync)
        return store.withLockUnchecked { $0.meta.lastSync }
    }

    /// The changes saved on the device that haven't reached iCloud yet, in the order of their record names, including the ones iCloud rejected.
    public var pending: [PendingChange<CKRecord>] {
        registrar.access(self, keyPath: \.pending)
        return store.withLockUnchecked { $0.pendingChanges() }.map { $0.change.map { $0.copy() as? CKRecord ?? $0 } }
    }

    /// A placeholder property that observers of the unsaved changes track.
    private var changes: Void { () }

    /// A placeholder property that observers of one zone's values of one type track.
    private subscript(table key: TableKey) -> Void { () }

    /// Stages the value's removal from the zone, saved with the next save.
    public func delete<R: RecordCodable & Identifiable>(_ value: R, zone: String = "Composition") {
        stage([RecordKey(name: Self.recordName(of: value), zone: zone): .delete])
    }

    /// Stages the removal of every value of the type in the zone that meets the predicate, or of all of them, saved with the next save.
    public func delete<R: RecordCodable>(_ type: R.Type, where predicate: Predicate<R>? = nil, zone: String = "Composition") throws {
        let names: [String] = try matches(RecordDescriptor(predicate: predicate, zone: zone)).map(\.name)
        stage(Dictionary(uniqueKeysWithValues: names.map { (RecordKey(name: $0, zone: zone), Change.delete) }))
    }

    /// The values the descriptor describes, including unsaved changes, read from the cache on the device.
    public func fetch<R: RecordCodable>(_ descriptor: RecordDescriptor<R>) throws -> [R] {
        try matches(descriptor).map(\.value)
    }

    /// The number of values the descriptor describes.
    public func fetchCount<R: RecordCodable>(_ descriptor: RecordDescriptor<R>) throws -> Int {
        try matches(descriptor).count
    }

    /// The identifiers of the records that keep the values the descriptor describes.
    public func fetchIdentifiers<R: RecordCodable>(_ descriptor: RecordDescriptor<R>) throws -> [CKRecord.ID] {
        try matches(descriptor).map { RecordKey(name: $0.name, zone: descriptor.zone).id }
    }

    /// Takes in the engine's events: its state, account changes, records fetched from iCloud, and the results of sending.
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            mutate { store, _ in
                store.meta.state = update.stateSerialization
                store.isMetaDirty = true
            }
        case .accountChange(let change):
            changeAccount(change.changeType)
        case .fetchedDatabaseChanges(let changes):
            changes.deletions.forEach { removeZone($0.zoneID.zoneName) }
        case .fetchedRecordZoneChanges(let changes):
            receive(changes.modifications.map(\.record), deleting: changes.deletions.map(\.recordID))
        case .sentRecordZoneChanges(let sent):
            settle(sent, syncEngine)
        case .willFetchChanges:
            track(\.fetches, 1, .isFetching)
        case .didFetchChanges:
            track(\.fetches, -1, .isFetching)
        case .willSendChanges:
            track(\.sends, 1, .isSending)
        case .didSendChanges:
            track(\.sends, -1, .isSending)
        default:
            break
        }
    }

    /// Stages the value to be saved in the zone under its identifier, replacing the value already there, saved with the next save.
    public func insert<R: RecordCodable & Identifiable>(_ value: R, zone: String = "Composition") throws {
        let key: RecordKey = RecordKey(name: Self.recordName(of: value), zone: zone)
        let saved: CKRecord? = store.withLockUnchecked { store in store.withTable(key.table) { $0.records[key.name] } }
        let record: CKRecord = saved.map { Self.rebased(CKRecord(recordType: $0.recordType, recordID: $0.recordID), onto: $0) } ?? CKRecord(recordType: Self.recordType(of: R.self), recordID: key.id)
        try value.encode(to: record)
        stage([key: .save(record, value)])
    }

    /// Builds the next batch of records to send from the changes waiting in the engine.
    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes: [CKSyncEngine.PendingRecordZoneChange] = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { [self] id in outgoing(id) }
    }

    /// The changes to values of the type in the zone that haven't reached iCloud yet, in the order of their record names, leaving out records that can't be decoded.
    public func pending<R: RecordCodable>(_ type: R.Type, zone: String = "Composition") -> [PendingChange<R>] {
        registrar.access(self, keyPath: \.pending)
        let table: TableKey = TableKey(type: Self.recordType(of: R.self), zone: zone)
        let changes: [(key: RecordKey, change: PendingChange<CKRecord>)] = store.withLockUnchecked { $0.pendingChanges() }.filter { $0.key.table == table }
        return changes.compactMap { try? $0.change.map { try R(from: $0) } }
    }

    /// A copy of the record with the identifier as the context has it, including unsaved changes, with its fields and server fields.
    public func record(for id: CKRecord.ID) -> CKRecord? {
        let key: RecordKey = RecordKey(id)
        registrar.access(self, keyPath: \.[table: key.table])
        let record: CKRecord? = store.withLockUnchecked { store in
            switch store.staged[key] {
            case .save(let record, _)?: return record
            case .delete?: return nil
            case nil: return store.withTable(key.table) { $0.records[key.name] }
            }
        }
        return record?.copy() as? CKRecord
    }

    /// Fetches the latest records from iCloud and sends every saved change, for `refreshable`, throwing when the app can't use CloudKit or the sync fails.
    public func refresh() async throws {
        guard let engine: CKSyncEngine = start() else { throw CKError(.missingEntitlement) }
        store.withLockUnchecked { requeue(engine, &$0) }
        try await engine.fetchChanges()
        try await engine.sendChanges()
    }

    /// Settles the conflict by keeping the version, sending it over the server's when it isn't the one already kept.
    public func resolve(_ conflict: RecordConflict, keeping version: CKRecord) {
        let engine: CKSyncEngine? = start()
        let key: RecordKey = RecordKey(conflict.id)
        let resends: Bool = mutate { store, signals in
            store.conflicts[conflict.id] = nil
            signals.insert(.conflicts)
            let current: CKRecord? = store.withTable(key.table) { $0.records[key.name] }
            guard let current: CKRecord, !Self.fieldsMatch(current, version) else { return false }
            store.withTable(key.table) { $0.set(Self.rebased(version, onto: current), named: key.name) }
            store.meta.pending.insert(key)
            store.dirty.insert(key.table)
            store.isMetaDirty = true
            signals.insert(.table(key.table))
            return true
        }
        if resends { engine?.state.add(pendingRecordZoneChanges: [.saveRecord(conflict.id)]) }
    }

    /// Discards every change made since the last save.
    public func rollback() {
        mutate { store, signals in
            signals.formUnion(store.staged.keys.map { .table($0.table) })
            signals.insert(.changes)
            store.staged = [:]
        }
    }

    /// Keeps every staged change in the cache on the device, written in the background, and queues it for iCloud.
    public func save() {
        let engine: CKSyncEngine? = start()
        let (changes, zones): ([CKSyncEngine.PendingRecordZoneChange], [String]) = mutate { store, signals in
            store.isAutosaving = false
            guard !store.staged.isEmpty else { return ([], []) }
            var changes: [CKSyncEngine.PendingRecordZoneChange] = []
            var zones: [String] = []
            let staged: [RecordKey: Change] = store.staged
            for (key, change) in staged {
                switch change {
                case .save(let record, let value):
                    store.withTable(key.table) { $0.set(record, named: key.name, value: value) }
                    changes.append(.saveRecord(key.id))
                case .delete:
                    store.withTable(key.table) { $0.set(nil, named: key.name) }
                    changes.append(.deleteRecord(key.id))
                }
                if store.meta.zones.insert(key.zone).inserted { zones.append(key.zone) }
                store.meta.pending.insert(key)
                store.dirty.insert(key.table)
            }
            store.isMetaDirty = true
            store.staged = [:]
            signals.formUnion([.changes, .pending])
            return (changes, zones)
        }
        engine?.state.add(pendingDatabaseChanges: zones.map { .saveZone(CKRecordZone(zoneName: $0)) })
        engine?.state.add(pendingRecordZoneChanges: changes)
    }

    /// Runs the block, then saves the changes it made.
    public func transaction(block: () throws -> Void) rethrows {
        try block()
        save()
    }

    /// Waits for every write still waiting to reach the disk.
    func flush() {
        writer.flush()
    }

    /// Takes in an account change, clearing the cache when the account signs out or switches, since its records belong to the previous account.
    private func changeAccount(_ change: CKSyncEngine.Event.AccountChange.ChangeType) {
        switch change {
        case .signIn:
            setAccount(.available)
        case .signOut:
            clear()
            setAccount(.noAccount)
        case .switchAccounts:
            clear()
            setAccount(.available)
        @unknown default:
            break
        }
    }

    /// Removes every record, change, conflict and error from the context and the device.
    private func clear() {
        let zones: [URL] = mutate { store, signals in
            signals.formUnion(store.tables.keys.map { .table($0) })
            signals.formUnion([.changes, .conflicts, .pending])
            store.conflicts = [:]
            store.errors = [:]
            store.staged = [:]
            store.tables = [:]
            store.dirty = []
            store.meta.pending = []
            store.isMetaDirty = true
            return store.meta.zones.map { store.folder.appending(component: $0, directoryHint: .isDirectory) }
        }
        writer.write(Dictionary(uniqueKeysWithValues: zones.map { ($0, Write.remove) }))
    }

    /// The values the descriptor describes with the names of their records, in its order and within its limit.
    private func matches<R: RecordCodable>(_ descriptor: RecordDescriptor<R>) throws -> [(name: String, value: R)] {
        let key: TableKey = TableKey(type: Self.recordType(of: R.self), zone: descriptor.zone)
        registrar.access(self, keyPath: \.[table: key])
        let entries: [(name: String, value: R)] = try store.withLockUnchecked { try $0.values(R.self, in: key) }
        let matching: [(name: String, value: R)] = try entries.filter { try descriptor.predicate?.evaluate($0.value) ?? true }
        let sorted: [(name: String, value: R)] = descriptor.sortBy.isEmpty ? matching : matching.sorted { first, second in descriptor.sortBy.lazy.map { $0.compare(first.value, second.value) }.first { $0 != .orderedSame } == .orderedAscending }
        return Array(sorted.prefix(descriptor.fetchLimit ?? sorted.count))
    }

    /// Changes the store under its lock, then writes what changed to disk and tells the observers of what the change touched.
    @discardableResult private func mutate<T>(_ change: (inout Store, inout Set<Signal>) throws -> T) rethrows -> T {
        var signals: Set<Signal> = []
        let (result, writes, isPendingChanged): (T, [URL: Write], Bool) = try store.withLockUnchecked { store in
            let pending: Set<RecordKey> = store.meta.pending
            let failures: Set<CKRecord.ID> = Set(store.errors.keys)
            let result: T = try change(&store, &signals)
            return (result, store.writes(), pending != store.meta.pending || failures != Set(store.errors.keys))
        }
        if isPendingChanged { signals.insert(.pending) }
        writer.write(writes)
        for signal: Signal in signals {
            switch signal {
            case .changes: registrar.withMutation(of: self, keyPath: \.changes) {}
            case .conflicts: registrar.withMutation(of: self, keyPath: \.conflicts) {}
            case .isFetching: registrar.withMutation(of: self, keyPath: \.isFetching) {}
            case .isSending: registrar.withMutation(of: self, keyPath: \.isSending) {}
            case .lastSync: registrar.withMutation(of: self, keyPath: \.lastSync) {}
            case .pending: registrar.withMutation(of: self, keyPath: \.pending) {}
            case .account: registrar.withMutation(of: self, keyPath: \.account) {}
            case .table(let key): registrar.withMutation(of: self, keyPath: \.[table: key]) {}
            }
        }
        return result
    }

    /// A copy of the saved record to send for the identifier, or `nil`, which drops the change, when the context no longer has it.
    private func outgoing(_ id: CKRecord.ID) -> CKRecord? {
        let key: RecordKey = RecordKey(id)
        return store.withLockUnchecked { store in store.withTable(key.table) { $0.records[key.name]?.copy() as? CKRecord } }
    }

    /// Takes in records changed and removed on other devices, keeping this device's versions of the records it hasn't finished sending.
    private func receive(_ records: [CKRecord], deleting ids: [CKRecord.ID]) {
        mutate { store, signals in
            for record: CKRecord in records {
                let key: RecordKey = RecordKey(record.recordID)
                let isPending: Bool = store.meta.pending.contains(key)
                let changed: Bool = store.withTable(key.table) { table in
                    let local: CKRecord? = table.records[key.name]
                    if isPending, let local: CKRecord {
                        table.set(Self.rebased(local, onto: record), named: key.name, value: table.values[key.name])
                        return false
                    }
                    let isSame: Bool = local.map { Self.fieldsMatch($0, record) } ?? false
                    table.set(record, named: key.name, value: isSame ? table.values[key.name] : nil)
                    return !isSame
                }
                store.dirty.insert(key.table)
                if changed { signals.insert(.table(key.table)) }
            }
            for id: CKRecord.ID in ids {
                let key: RecordKey = RecordKey(id)
                guard !store.meta.pending.contains(key), store.withTable(key.table, { $0.records[key.name] != nil }) else { continue }
                store.withTable(key.table) { $0.set(nil, named: key.name) }
                store.dirty.insert(key.table)
                signals.insert(.table(key.table))
            }
        }
    }

    /// Removes a zone deleted on the server, with every record and change in it.
    private func removeZone(_ zone: String) {
        let folder: URL = mutate { store, signals in
            let keys: [TableKey] = store.tables.keys.filter { $0.zone == zone }
            signals.formUnion(keys.map { .table($0) })
            signals.insert(.changes)
            keys.forEach { store.tables[$0] = nil }
            store.dirty = store.dirty.filter { $0.zone != zone }
            store.staged = store.staged.filter { $0.key.zone != zone }
            store.meta.pending = store.meta.pending.filter { $0.zone != zone }
            store.meta.zones.remove(zone)
            store.isMetaDirty = true
            return store.folder.appending(component: zone, directoryHint: .isDirectory)
        }
        writer.write([folder: .remove])
    }

    /// Queues every change saved on the device that hasn't reached iCloud, so unsent and rejected changes are tried again.
    private func requeue(_ engine: CKSyncEngine, _ store: inout Store) {
        let keys: Set<RecordKey> = store.meta.pending
        let changes: [CKSyncEngine.PendingRecordZoneChange] = keys.map { key in store.withTable(key.table) { $0.records[key.name] } == nil ? .deleteRecord(key.id) : .saveRecord(key.id) }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Records the account status, telling observers only when it changed.
    private func setAccount(_ account: CKAccountStatus) {
        mutate { store, signals in
            guard store.account != account else { return }
            store.account = account
            signals.insert(.account)
        }
    }

    /// Settles the results of sending: confirms saves and deletions, keeps this device's version of a conflict while recording the server's, recreates records and zones removed from the server, and records every other failure.
    private func settle(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, _ engine: CKSyncEngine) {
        mutate { store, signals in
            for saved: CKRecord in sent.savedRecords {
                let key: RecordKey = RecordKey(saved.recordID)
                let isCurrent: Bool = store.withTable(key.table) { table in
                    guard let local: CKRecord = table.records[key.name] else { return false }
                    let isCurrent: Bool = Self.fieldsMatch(local, saved)
                    table.set(isCurrent ? saved : Self.rebased(local, onto: saved), named: key.name, value: table.values[key.name])
                    return isCurrent
                }
                if isCurrent { store.meta.pending.remove(key) }
                store.errors[saved.recordID] = nil
                store.dirty.insert(key.table)
            }
            for id: CKRecord.ID in sent.deletedRecordIDs {
                let key: RecordKey = RecordKey(id)
                if !store.withTable(key.table, { $0.records[key.name] != nil }) { store.meta.pending.remove(key) }
                store.errors[id] = nil
            }
            for failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave in sent.failedRecordSaves {
                let id: CKRecord.ID = failure.record.recordID
                let key: RecordKey = RecordKey(id)
                guard let local: CKRecord = store.withTable(key.table, { $0.records[key.name] }) else { continue }
                if failure.error.code == .serverRecordChanged, let server: CKRecord = failure.error.serverRecord {
                    let isSame: Bool = Self.fieldsMatch(local, server)
                    store.withTable(key.table) { $0.set(isSame ? server : Self.rebased(local, onto: server), named: key.name, value: $0.values[key.name]) }
                    store.dirty.insert(key.table)
                    if isSame {
                        store.meta.pending.remove(key)
                    } else {
                        store.conflicts[id] = RecordConflict(id: id, local: local, server: server)
                        signals.insert(.conflicts)
                        engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                    }
                } else if failure.error.code == .unknownItem || failure.error.code == .zoneNotFound {
                    store.withTable(key.table) { $0.set(Self.rebased(local, onto: CKRecord(recordType: local.recordType, recordID: id)), named: key.name, value: $0.values[key.name]) }
                    store.dirty.insert(key.table)
                    if failure.error.code == .zoneNotFound { engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: id.zoneID))]) }
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                } else {
                    store.errors[id] = failure.error
                }
            }
            for (id, error) in sent.failedRecordDeletes {
                if error.code == .unknownItem {
                    store.meta.pending.remove(RecordKey(id))
                } else {
                    store.errors[id] = error
                }
            }
            store.isMetaDirty = true
            signals.insert(.pending)
        }
    }

    /// Stages the changes, telling observers of the values they touch, and schedules a save when autosave is on.
    private func stage(_ changes: [RecordKey: Change]) {
        guard !changes.isEmpty else { return }
        let schedules: Bool = mutate { store, signals in
            store.staged.merge(changes) { $1 }
            signals.formUnion(changes.keys.map { .table($0.table) })
            signals.insert(.changes)
            guard store.autosaveEnabled, !store.isAutosaving else { return false }
            store.isAutosaving = true
            return true
        }
        if schedules { Task { @MainActor [self] in save() } }
    }

    /// Creates the engine on first use, queuing every change an earlier launch left unsent, or returns `nil` when the app can't use CloudKit.
    @discardableResult private func start() -> CKSyncEngine? {
        guard hasCloudKitEntitlement else { return nil }
        let (engine, isNew): (CKSyncEngine, Bool) = store.withLockUnchecked { store in
            if let engine: CKSyncEngine = store.engine { return (engine, false) }
            let engine: CKSyncEngine = CKSyncEngine(CKSyncEngine.Configuration(database: container.privateCloudDatabase, stateSerialization: store.meta.state, delegate: self))
            if store.meta.state == nil { engine.state.add(pendingDatabaseChanges: store.meta.zones.map { .saveZone(CKRecordZone(zoneName: $0)) }) }
            requeue(engine, &store)
            store.engine = engine
            return (engine, true)
        }
        if isNew { Task { [self] in setAccount((try? await container.accountStatus()) ?? .couldNotDetermine) } }
        return engine
    }

    /// Counts a fetch or send starting or finishing, telling observers when one starts or the last one finishes, and recording when it finished.
    private func track(_ count: WritableKeyPath<Store, Int>, _ step: Int, _ signal: Signal) {
        mutate { store, signals in
            let wasActive: Bool = store[keyPath: count] > 0
            store[keyPath: count] = max(store[keyPath: count] + step, 0)
            if wasActive != (store[keyPath: count] > 0) { signals.insert(signal) }
            guard step < 0 else { return }
            store.meta.lastSync = .now
            store.isMetaDirty = true
            signals.insert(.lastSync)
        }
    }
}

/// A staged change to one record: a save with the record and the value it keeps, or a deletion.
fileprivate enum Change {

    case delete
    case save(CKRecord, Any)

    /// A Boolean value indicating whether the change saves a record.
    var isSave: Bool {
        if case .save = self { return true }
        return false
    }
}

fileprivate extension PendingChange {

    /// The change with its value transformed, keeping its kind, identifier and error.
    func map<T>(_ transform: (V) throws -> T) rethrows -> PendingChange<T> {
        switch self {
        case .insert(let value): return try .insert(transform(value))
        case .update(let value): return try .update(transform(value))
        case .delete(let id): return .delete(id)
        case .failed(let id, let value, let error): return try .failed(id, value.map(transform), error)
        }
    }
}

/// What the context keeps on the device besides the records: the engine's state, the last sync, the zones in use, and the records waiting to reach iCloud.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate struct Meta: Codable {

    var lastSync: Date?
    var pending: Set<RecordKey> = []
    var state: CKSyncEngine.State.Serialization?
    var zones: Set<String> = []
}

/// A record's name and zone, where the name starts with its type, as in `Note.42`.
fileprivate struct RecordKey: Codable, Hashable, Sendable {

    let name: String
    let zone: String

    /// Creates the key for the record name in the zone.
    init(name: String, zone: String) {
        self.name = name
        self.zone = zone
    }

    /// Creates the key for the record identifier.
    init(_ id: CKRecord.ID) {
        self.init(name: id.recordName, zone: id.zoneID.zoneName)
    }

    /// The record's identifier.
    var id: CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: CKRecordZone.ID(zoneName: zone))
    }

    /// The table that keeps the record, named after the type at the start of its name.
    var table: TableKey {
        TableKey(type: String(name.prefix { $0 != "." }), zone: zone)
    }
}

/// Something observers track: a status, the unsaved changes, or one zone's values of one type.
fileprivate enum Signal: Hashable {

    case account
    case changes
    case conflicts
    case isFetching
    case isSending
    case lastSync
    case pending
    case table(TableKey)
}

/// Everything the context keeps in memory, guarded by its lock, with what still needs writing to disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate struct Store {

    let folder: URL
    var account: CKAccountStatus = .couldNotDetermine
    var autosaveEnabled: Bool = true
    var conflicts: [CKRecord.ID: RecordConflict] = [:]
    var dirty: Set<TableKey> = []
    var engine: CKSyncEngine?
    var errors: [CKRecord.ID: CKError] = [:]
    var fetches: Int = 0
    var isAutosaving: Bool = false
    var isMetaDirty: Bool = false
    var meta: Meta
    var sends: Int = 0
    var staged: [RecordKey: Change] = [:]
    var tables: [TableKey: Table] = [:]

    /// Creates the store for the folder, reading what an earlier launch kept there.
    init(folder: URL) {
        self.folder = folder
        self.meta = (try? Data(contentsOf: folder.appending(component: "_context.plist"))).flatMap { try? PropertyListDecoder().decode(Meta.self, from: $0) } ?? Meta()
    }

    /// The changes saved on the device that haven't reached iCloud, with their keys, in the order of their record names.
    mutating func pendingChanges() -> [(key: RecordKey, change: PendingChange<CKRecord>)] {
        let keys: [RecordKey] = meta.pending.sorted { ($0.zone, $0.name) < ($1.zone, $1.name) }
        return keys.map { key -> (key: RecordKey, change: PendingChange<CKRecord>) in
            let record: CKRecord? = withTable(key.table) { $0.records[key.name] }
            if let error: CKError = errors[key.id] { return (key, .failed(key.id, record, error)) }
            guard let record: CKRecord else { return (key, .delete(key.id)) }
            return (key, record.recordChangeTag == nil ? .insert(record) : .update(record))
        }
    }

    /// The values of the type kept in the table, with the staged changes applied, in the order of their record names, decoding each record once.
    mutating func values<R: RecordCodable>(_ type: R.Type, in key: TableKey) throws -> [(name: String, value: R)] {
        let staged: [String: Change] = Dictionary(uniqueKeysWithValues: self.staged.filter { $0.key.table == key }.map { ($0.key.name, $0.value) })
        return try withTable(key) { table in
            let names: [String] = Set(table.records.keys).union(staged.keys).sorted()
            return try names.compactMap { name -> (name: String, value: R)? in
                switch staged[name] {
                case .delete?:
                    return nil
                case .save(_, let value as R)?:
                    return (name, value)
                case .save(let record, _)?:
                    return try (name, R(from: record))
                case nil:
                    if let value: R = table.values[name] as? R { return (name, value) }
                    guard let record: CKRecord = table.records[name] else { return nil }
                    let value: R = try R(from: record)
                    table.values[name] = value
                    return (name, value)
                }
            }
        }
    }

    /// Changes the table, reading it from its file on first use.
    mutating func withTable<T>(_ key: TableKey, _ change: (inout Table) throws -> T) rethrows -> T {
        if tables[key] == nil { tables[key] = Table(contentsOf: key.url(in: folder)) }
        return try change(&tables[key, default: Table()])
    }

    /// The files to write for every table and for the meta changed since the last call.
    mutating func writes() -> [URL: Write] {
        var writes: [URL: Write] = Dictionary(uniqueKeysWithValues: dirty.map { ($0.url(in: folder), Write.archives(tables[$0]?.archives ?? [:])) })
        if isMetaDirty, let data: Data = try? PropertyListEncoder.binary.encode(meta) { writes[folder.appending(component: "_context.plist")] = .data(data) }
        dirty = []
        isMetaDirty = false
        return writes
    }
}

/// One zone's records of one type, kept as records, as archives ready to write, and as the values they decode to.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate struct Table {

    var archives: [String: Data] = [:]
    var records: [String: CKRecord] = [:]
    var values: [String: Any] = [:]

    /// Creates an empty table.
    init() {}

    /// Reads the table from its file, or creates an empty one when there is none.
    init(contentsOf url: URL) {
        self.archives = (try? Data(contentsOf: url)).flatMap { try? PropertyListDecoder().decode([String: Data].self, from: $0) } ?? [:]
        self.records = archives.compactMapValues(RecordContext.record(from:))
    }

    /// Keeps the record under the name, or removes it for `nil`, along with the value it decodes to when known.
    mutating func set(_ record: CKRecord?, named name: String, value: Any? = nil) {
        archives[name] = record.map(RecordContext.archive)
        records[name] = record
        values[name] = value
    }
}

/// One zone's records of one type, which share a file.
fileprivate struct TableKey: Hashable, Sendable {

    let type: String
    let zone: String

    /// The file that keeps the table, inside its zone's folder.
    func url(in folder: URL) -> URL {
        folder.appending(components: zone, "\(type).plist")
    }
}

/// A file to write: a table's archives, encoded data, or a removal.
fileprivate enum Write: Sendable {

    case archives([String: Data])
    case data(Data)
    case remove

    /// A Boolean value indicating whether the write removes the file or folder.
    var isRemoval: Bool {
        if case .remove = self { return true }
        return false
    }

    /// Writes the file atomically at the URL, or removes the file or folder there.
    func save(to url: URL) {
        let data: Data? = switch self {
        case .archives(let archives): try? PropertyListEncoder.binary.encode(archives)
        case .data(let data): data
        case .remove: nil
        }
        guard let data: Data else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

/// Writes files in the background in order, where a newer write to a file replaces one still waiting, and removals run first.
fileprivate final class Writer: Sendable {

    private let queue: DispatchQueue = DispatchQueue(label: "Composition.RecordContext", qos: .utility)
    private let waiting: OSAllocatedUnfairLock<[URL: Write]> = OSAllocatedUnfairLock(initialState: [:])

    /// Waits for every write still waiting to reach the disk.
    func flush() {
        queue.sync {}
    }

    /// Queues the writes, starting a background pass when none is waiting.
    func write(_ writes: [URL: Write]) {
        guard !writes.isEmpty else { return }
        let isIdle: Bool = waiting.withLock { waiting in
            defer { waiting.merge(writes) { $1 } }
            return waiting.isEmpty
        }
        guard isIdle else { return }
        queue.async { [self] in
            let batch: [URL: Write] = waiting.withLock { waiting in
                defer { waiting = [:] }
                return waiting
            }
            batch.filter(\.value.isRemoval).forEach { $0.value.save(to: $0.key) }
            batch.filter { !$0.value.isRemoval }.forEach { $0.value.save(to: $0.key) }
        }
    }
}

fileprivate extension PropertyListEncoder {

    /// An encoder that writes the compact binary format.
    static var binary: PropertyListEncoder {
        let encoder: PropertyListEncoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
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
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension EnvironmentValues {

    /// The record context views read and write through, which defaults to one for the app's default container.
    var recordContext: RecordContext {
        get { self[RecordContextKey.self] }
        set { self[RecordContextKey.self] = newValue }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension View {

    /// Sets the record context the view and its descendants read and write through, like `modelContext(_:)`.
    func recordContext(_ context: RecordContext) -> some View {
        environment(\.recordContext, context)
    }
}

/// The environment key of the record context, created on first use.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate struct RecordContextKey: EnvironmentKey {

    static let defaultValue: RecordContext = RecordContext()
}
#endif
