// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorage.swift
// dependencies: []
// permissions: [aps-environment, com.apple.developer.icloud-container-identifiers, com.apple.developer.icloud-services, UIBackgroundModes]

// Setup in Xcode:
// 1. Select the app target, open Signing & Capabilities, click + Capability, and add iCloud.
// 2. Under iCloud, check CloudKit and select or create the container named iCloud. followed by the bundle identifier, which SyncedStorage uses.
// 3. Click + Capability again and add Push Notifications, so other devices' changes arrive without waiting for the next launch.
// 4. On iOS, also add Background Modes and check Remote notifications.
// 5. Run on a device or simulator signed in to iCloud. Values stay on the device while signed out and sync once an account is available.
// 6. Nothing is needed in the CloudKit Console during development, since the first save creates the SyncedStorage record type in the Development environment.
// 7. Before TestFlight or the App Store, open the CloudKit Console at https://icloud.developer.apple.com, choose the container, and click Deploy Schema Changes to copy the schema to Production.

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

/// The state of a value's last sync, shaped like `Result`, with the date of the last success or the error CloudKit or the network gave.
public enum SyncStatus: Sendable {

    /// Not synced since launch, and no earlier success is known.
    case unknown

    /// Waiting on a sync that is under way.
    case syncing

    /// Synced successfully at the date.
    case success(Date)

    /// The last sync failed with the error, such as a `CKError` or `URLError`.
    case failure(any Error)
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

    private let defaultValue: Value
    private let key: String
    private let query: SyncedQuery<Value>?

    /// Creates storage for the key that returns the default value until something is stored.
    public init(wrappedValue: Value, _ key: String) {
        self.init(wrappedValue: wrappedValue, key, query: nil)
    }

    /// Creates storage for the key that returns `nil` until something is stored.
    public init(_ key: String) where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil, key)
    }

    /// Creates storage for the key whose identifiable elements, each synced on its own, read through the filter and sorted by the descriptors.
    public init<I: Codable & Identifiable & Sendable>(wrappedValue: Value, _ key: String, filter: Predicate<I>? = nil, sort descriptors: [SortDescriptor<I>] = []) where Value: RangeReplaceableCollection, Value.Element == I {
        self.init(wrappedValue: wrappedValue, key, query: SyncedQuery(key, filter: filter, sort: descriptors))
    }

    /// Creates storage for the key whose identifiable elements, each synced on its own, read through the filter and sorted by the key path.
    public init<I: Codable & Identifiable & Sendable, C: Comparable>(wrappedValue: Value, _ key: String, filter: Predicate<I>? = nil, sort keyPath: KeyPath<I, C> & Sendable, order: SortOrder = .forward) where Value: RangeReplaceableCollection, Value.Element == I {
        self.init(wrappedValue: wrappedValue, key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// Creates storage for the key whose identifiable elements, each synced on its own, read through the filter and sorted by the optional key path.
    public init<I: Codable & Identifiable & Sendable, C: Comparable>(wrappedValue: Value, _ key: String, filter: Predicate<I>? = nil, sort keyPath: KeyPath<I, C?> & Sendable, order: SortOrder = .forward) where Value: RangeReplaceableCollection, Value.Element == I {
        self.init(wrappedValue: wrappedValue, key, filter: filter, sort: [SortDescriptor(keyPath, order: order)])
    }

    /// Creates storage for the key that reads and writes through the query, when there is one, stopping on a key that contains "/" or starts with "_", which name a list's items and the engine's own file.
    private init(wrappedValue: Value, _ key: String, query: SyncedQuery<Value>?) {
        precondition(!key.contains("/") && !key.hasPrefix("_"), "The SyncedStorage key \"\(key)\" can't contain \"/\", which separates a list from its items, or start with \"_\", which CloudKit reserves.")
        self.defaultValue = wrappedValue
        self.key = key
        self.query = query
    }

    /// The value kept on the device, or the default value when nothing is stored, where an array or `Collection` of identifiable elements syncs each element on its own and reads through the filter in the order written or the sort's; setting `nil` removes it.
    public var wrappedValue: Value {
        get {
            if let Items: any SyncedItems.Type = Value.self as? any SyncedItems.Type, let items: Value = Items.init(syncedUnder: key) as? Value { return query?.read(items) ?? items }
            if let items: any SyncedItems = defaultValue as? any SyncedItems { return items.attached(to: key) as? Value ?? defaultValue }
            guard let data: Data = SyncEngine.shared.value(key), let value: Value = DecodedValues.decode(Value.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            if Value.self is any SyncedItems.Type, let items: any SyncedItems = (query?.merge(newValue) ?? newValue) as? any SyncedItems { return items.sync(under: key, positioned: !(query?.isSorted ?? false)) }
            let data: Data? = (try? JSONEncoder().encode(newValue)).flatMap { $0 == Data("null".utf8) ? nil : $0 }
            SyncEngine.shared.write([key: data])
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
        guard let data: Data = SyncEngine.shared.syncedValue(key), let value: Value = DecodedValues.decode(Value.self, from: data) else { return defaultValue }
        return value
    }

    /// Fetches the latest values from iCloud in the background, moving the status to syncing and then to success or failure.
    func refresh() {
        SyncEngine.shared.refresh(key)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension SyncedStorage where Value: Identifiable {

    /// A change to an item of a list that hasn't reached iCloud yet.
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

    /// A list kept by SyncedStorage that works like an array and reports how its sync is going.
    struct Collection: Codable, ExpressibleByArrayLiteral, MutableCollection, RandomAccessCollection, RangeReplaceableCollection, Sendable {

        fileprivate let key: String?
        fileprivate var items: [Value]

        /// Creates an empty list.
        public init() {
            self.init([], key: nil)
        }

        /// Creates a list of the items.
        public init(arrayLiteral items: Value...) {
            self.init(items, key: nil)
        }

        /// Decodes the list from an array of its items.
        public init(from decoder: any Decoder) throws {
            self.init(try [Value](from: decoder), key: nil)
        }

        /// Creates a list of the items that reports the sync of the list kept under the key.
        fileprivate init(_ items: [Value], key: String?) {
            self.key = key
            self.items = items
        }

        /// The item kept in the data, if any.
        private static func item(_ data: Data?) -> Value? {
            data.flatMap { DecodedValues.decode(SyncedItem<Value>.self, from: $0)?.value }
        }

        /// The entries ordered by when they were written, oldest first.
        private static func oldestFirst(_ entries: [String: SyncEntry]) -> [SyncEntry] {
            entries.values.sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
        }

        /// The position after the last item.
        public var endIndex: Int {
            items.endIndex
        }

        /// The changes made on this device that haven't reached iCloud yet, failed ones included, oldest first, kept on the device until they do.
        public var pending: [Change] {
            guard let key else { return [] }
            return Self.oldestFirst(SyncEngine.shared.entries(under: key)).compactMap { entry in
                if case .failure(let error) = entry.status, let item: Value = Self.item(entry.value ?? entry.confirmed) { return .failed(item, error as? CKError ?? CKError(.internalError)) }
                guard entry.isPending else { return nil }
                if let item: Value = Self.item(entry.value) { return entry.confirmed == nil && entry.record == nil ? .insert(item) : .update(item) }
                return Self.item(entry.confirmed).map(Change.remove)
            }
        }

        /// The position of the first item.
        public var startIndex: Int {
            items.startIndex
        }

        /// The state of the list's last sync, starting at the last success kept on the device.
        public var status: SyncStatus {
            guard let key else { return .unknown }
            return SyncEngine.shared.status(key)
        }

        /// The item at the position.
        public subscript(position: Int) -> Value {
            get { items[position] }
            set { items[position] = newValue }
        }

        /// Encodes the list as an array of its items.
        public func encode(to encoder: any Encoder) throws {
            try items.encode(to: encoder)
        }

        /// When the item was last written, on any device, or `nil` when it isn't kept.
        public func modified(_ item: Value) -> Date? {
            guard let key else { return nil }
            return SyncEngine.shared.entry("\(key)/\(item.id)")?.modified
        }

        /// Fetches the latest items from iCloud and sends every waiting change in the background, reporting the result through `status`.
        public func refresh() {
            guard let key else { return }
            SyncEngine.shared.refresh(key)
        }

        /// Fetches the latest items from iCloud and sends every waiting change, throwing the error a failure gave, such as a lost connection.
        public func refresh() async throws {
            guard let key else { return }
            try await SyncEngine.shared.refresh(key)
        }

        /// Replaces the items in the range with the new ones.
        public mutating func replaceSubrange<C: Swift.Collection>(_ subrange: Range<Int>, with newItems: C) where C.Element == Value {
            items.replaceSubrange(subrange, with: newItems)
        }
    }
}

/// Keeps every synced value in a file on the device and syncs them through the private iCloud database, where the newest write wins, tracking each key's status.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class SyncEngine: CKSyncEngineDelegate, Observable, Sendable {

    private let engine: OSAllocatedUnfairLock<CKSyncEngine?> = OSAllocatedUnfairLock(uncheckedState: nil)
    private let entries: OSAllocatedUnfairLock<[String: SyncEntry]>
    private let registrar: ObservationRegistrar = ObservationRegistrar()

    /// Restores the values kept on the device, each starting at its last success, or unknown when it never synced.
    private init() {
        let stored: [String: SyncEntry] = Self.folder.readAll([String: SyncEntry].self).values.reduce(into: [:]) { stored, file in stored.merge(file) { kept, _ in kept } }
        self.entries = OSAllocatedUnfairLock(initialState: stored.mapValues { entry in
            var restored: SyncEntry = entry
            restored.status = entry.failure.map { .failure(CKError(CKError.Code(rawValue: $0) ?? .internalError)) } ?? entry.synced.map(SyncStatus.success) ?? .unknown
            return restored
        })
    }

    /// The engine every synced value shares.
    static let shared: SyncEngine = SyncEngine()

    /// The folder that keeps each key's values in a file named after the key, and the engine's state in `_engine.json`, a name no key can take.
    private static let folder: DeviceFolder = DeviceFolder("SyncedStorage")

    /// Whether a write waiting on the device should replace the server's value, which only a strictly newer write does.
    static func prefersLocal(written local: Date?, over server: Date?) -> Bool {
        guard let local: Date else { return false }
        return local > server ?? .distantPast
    }

    /// The CloudKit limit a record named after the key and holding the data would break, or `nil` when it fits: an ASCII name of at most 255 characters that doesn't start with an underscore, and data under 1 MB.
    static func recordViolation(named key: String, holding data: Data?) -> String? {
        if key.hasPrefix("_") || !key.allSatisfy(\.isASCII) { return "The key \"\(key)\" must be ASCII and not start with an underscore to name a CloudKit record." }
        if key.utf8.count > 255 { return "The key \"\(key)\" is over the 255 characters a CloudKit record name has room for." }
        if let data: Data, data.count >= 1_000_000 { return "The value for \"\(key)\" is \(data.count) bytes, over the 1 MB a CloudKit record holds." }
        return nil
    }

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

    /// The name of the file that keeps the key, which for an item of a list is the list's key.
    private static func fileName(_ key: String) -> String {
        String(key.prefix { $0 != "/" })
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
            Self.folder.write(update.stateSerialization, named: "_engine")
        case .accountChange(let change):
            switch change.changeType {
            case .signIn: return
            case .signOut: updateAll { entry in entry = SyncEntry(failure: CKError.Code.notAuthenticated.rawValue, status: .failure(CKError(.notAuthenticated)), value: entry.value) }
            default: updateAll { entry in entry = SyncEntry(value: entry.value) }
            }
        case .fetchedDatabaseChanges(let changes):
            guard changes.deletions.contains(where: { $0.zoneID == zoneID }) else { return }
            updateAll { entry in entry = SyncEntry(isPending: entry.isPending, modified: entry.modified, value: entry.value) }
        case .fetchedRecordZoneChanges(let changes):
            changes.modifications.forEach { receive($0.record) }
            changes.deletions.forEach { remove($0.recordID) }
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

    /// Fetches the latest values from iCloud in the background and sends every waiting write, failed ones included, recording the result as the key's status.
    func refresh(_ key: String) {
        guard start() != nil else {
            report(.failure(CKError(.missingEntitlement)), for: key)
            return
        }
        report(.syncing, for: key)
        Task { try? await refresh(key) }
    }

    /// Fetches the latest values from iCloud and sends every waiting write, failed ones included, recording the result as the key's status and throwing the error a failure gave.
    func refresh(_ key: String) async throws {
        guard let engine: CKSyncEngine = start() else {
            let error: CKError = CKError(.missingEntitlement)
            report(.failure(error), for: key)
            throw error
        }
        report(.syncing, for: key)
        requeue(engine)
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            report(.failure(error), for: key)
            throw error
        }
        switch entries.withLock({ $0[key]?.status }) {
        case .failure(let error)?: throw error
        default: report(.success(.now), for: key)
        }
    }

    /// The status of the key's last sync.
    func status(_ key: String) -> SyncStatus {
        registrar.access(self, keyPath: \.revision)
        return entries.withLock { $0[key]?.status ?? .unknown }
    }

    /// The entry kept on the device for the key.
    fileprivate func entry(_ key: String) -> SyncEntry? {
        registrar.access(self, keyPath: \.revision)
        return entries.withLock { $0[key] }
    }

    /// The entries kept on the device under the key, as the item keys `key/id` of an array synced item by item.
    fileprivate func entries(under key: String) -> [String: SyncEntry] {
        registrar.access(self, keyPath: \.revision)
        start()
        return entries.withLock { entries in entries.filter { $0.key.hasPrefix(key + "/") } }
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

    /// The values kept on the device under the key, as the item keys `key/id` of an array synced item by item.
    func values(under key: String) -> [String: Data] {
        registrar.access(self, keyPath: \.revision)
        start()
        return entries.withLock { entries in entries.filter { $0.key.hasPrefix(key + "/") }.compactMapValues(\.value) }
    }

    /// Keeps each key's value on the device, where `nil` removes it, and queues them for iCloud together, stopping debug builds on a value CloudKit can't hold.
    func write(_ changes: [String: Data?]) {
        assert(changes.allSatisfy { Self.recordViolation(named: $0.key, holding: $0.value) == nil }, changes.lazy.compactMap { Self.recordViolation(named: $0.key, holding: $0.value) }.first ?? "")
        let date: Date = .now
        let engine: CKSyncEngine? = start()
        let queues: Bool = engine != nil
        save(Set(changes.keys)) { entries in
            for (key, data) in changes {
                if queues { entries[key, default: SyncEntry()].isPending = true }
                entries[key, default: SyncEntry()].modified = date
                entries[key, default: SyncEntry()].value = data
            }
        }
        let pending: [CKSyncEngine.PendingRecordZoneChange] = changes.map { key, data in data == nil ? .deleteRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) : .saveRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) }
        engine?.state.add(pendingRecordZoneChanges: pending)
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
        }
        report(.success(date), for: record.recordID.recordName)
    }

    /// Marks a removed record's key as synced now.
    private func confirmDeletion(_ id: CKRecord.ID) {
        let date: Date = .now
        update(id.recordName) { entry in
            entry.confirmed = nil
            entry.isPending = false
            entry.record = nil
        }
        report(.success(date), for: id.recordName)
    }

    /// Records the error as the key's status, and the list's when the key is an item's.
    private func fail(_ key: String, _ error: any Error) {
        report(.failure(error), for: key)
    }

    /// Takes in a record from iCloud, adopting its value unless a newer write on the device is waiting to replace it.
    private func receive(_ record: CKRecord) {
        let fields: Data = Self.systemFields(of: record)
        let modified: Date? = record["modified"] as? Date
        let value: Data? = record["value"] as? Data
        let date: Date = record.modificationDate ?? .now
        let adopted: Bool = update(record.recordID.recordName) { entry in
            entry.confirmed = value
            entry.record = fields
            guard !entry.isPending || !Self.prefersLocal(written: entry.modified, over: modified) else { return false }
            entry.isPending = false
            entry.modified = modified
            entry.value = value
            return true
        }
        if adopted { report(.success(date), for: record.recordID.recordName) }
    }

    /// Builds the record to send for the key with the time it was written, or `nil`, which drops the change, when nothing waits to be sent.
    private func record(for id: CKRecord.ID) -> CKRecord? {
        guard let entry: SyncEntry = entries.withLock({ $0[id.recordName] }), entry.isPending, let value: Data = entry.value else { return nil }
        let record: CKRecord = entry.record.flatMap(Self.record(fromSystemFields:)) ?? CKRecord(recordType: "SyncedStorage", recordID: id)
        record["modified"] = entry.modified
        record["value"] = value
        return record
    }

    /// Takes in a record removed on another device, removing the value unless a write on this device is waiting to recreate it.
    private func remove(_ id: CKRecord.ID) {
        update(id.recordName) { entry in
            entry.confirmed = nil
            entry.record = nil
            guard !entry.isPending else { return }
            entry.value = nil
        }
    }

    /// Settles a failed save: a conflict by keeping the newer write, a missing record or zone by creating it again, and anything else as a failure.
    private func resolve(_ record: CKRecord, _ error: CKError, _ engine: CKSyncEngine) {
        let key: String = record.recordID.recordName
        switch error.code {
        case .serverRecordChanged:
            guard let server: CKRecord = error.serverRecord else { break }
            receive(server)
            if entries.withLock({ $0[key]?.isPending ?? false }) { engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)]) }
            return
        case .unknownItem, .zoneNotFound:
            update(key) { $0.record = nil }
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            return
        default:
            break
        }
        fail(key, error)
    }

    /// Queues every write still waiting on the device, so unsent and failed changes are tried again.
    private func requeue(_ engine: CKSyncEngine) {
        let unsent: [CKSyncEngine.PendingRecordZoneChange] = entries.withLock { $0.filter(\.value.isPending) }.map { key, entry in entry.value == nil ? .deleteRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) : .saveRecord(CKRecord.ID(recordName: key, zoneID: zoneID)) }
        engine.state.add(pendingRecordZoneChanges: unsent)
    }

    /// Records the status for the key and, when the key is an item's, for its list, keeping a success's date and a CloudKit failure's code on the device.
    private func report(_ status: SyncStatus, for key: String) {
        let keys: Set<String> = [key, Self.fileName(key)]
        save(keys) { entries in
            for key: String in keys {
                entries[key, default: SyncEntry()].status = status
                switch status {
                case .success(let date):
                    entries[key]?.failure = nil
                    entries[key]?.synced = date
                case .failure(let error):
                    entries[key]?.failure = (error as? CKError)?.code.rawValue
                case .syncing, .unknown:
                    break
                }
            }
        }
    }

    /// Changes the entries, keeps the files of the keys, or of every key when `nil`, on the device, and tells observers.
    @discardableResult private func save<R: Sendable>(_ keys: Set<String>?, _ change: @Sendable (inout [String: SyncEntry]) -> R) -> R {
        registrar.withMutation(of: self, keyPath: \.revision) {
            entries.withLock { entries in
                let result: R = change(&entries)
                let files: Set<String> = Set((keys ?? Set(entries.keys)).map(Self.fileName))
                for file: String in files {
                    Self.folder.write(entries.filter { Self.fileName($0.key) == file }, named: file)
                }
                return result
            }
        }
    }

    /// Creates the engine on first use, queuing every write an earlier launch left unsent, or returns `nil` when the app can't use CloudKit.
    @discardableResult private func start() -> CKSyncEngine? {
        guard hasCloudKitEntitlement else { return nil }
        return engine.withLockUnchecked { stored in
            if let stored { return stored }
            let serialization: CKSyncEngine.State.Serialization? = Self.folder.read(CKSyncEngine.State.Serialization.self, named: "_engine")
            let created: CKSyncEngine = CKSyncEngine(CKSyncEngine.Configuration(database: CKContainer.default().privateCloudDatabase, stateSerialization: serialization, delegate: self))
            if serialization == nil { created.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))]) }
            requeue(created)
            stored = created
            return created
        }
    }

    /// Changes the key's entry, keeps its file on the device, and tells observers.
    @discardableResult private func update<R: Sendable>(_ key: String, _ change: @Sendable (inout SyncEntry) -> R) -> R {
        save([key]) { change(&$0[key, default: SyncEntry()]) }
    }

    /// Changes every entry, keeps them on the device, and tells observers.
    private func updateAll(_ change: @Sendable (inout SyncEntry) -> Void) {
        save(nil) { entries in
            entries = entries.mapValues { entry in
                var changed: SyncEntry = entry
                change(&changed)
                return changed
            }
        }
    }
}

/// A value that SyncedStorage keeps as separate records, one per item, so changes to different items on different devices all survive.
protocol SyncedItems {

    /// Reads the items kept under the key, or `nil` when none were ever stored.
    init?(syncedUnder key: String)

    /// The same items, reporting the sync of the list kept under the key where they can.
    func attached(to key: String) -> Self

    /// Keeps the items under the key, writing only the items that were added, changed, removed or, when positioned, moved.
    func sync(under key: String, positioned: Bool)
}

extension Array: SyncedItems where Element: Codable & Identifiable {

    /// Reads the items kept under the key in order, or `nil` when none were ever stored.
    init?(syncedUnder key: String) {
        guard SyncEngine.shared.value(key) != nil else { return nil }
        let items: [(key: String, item: SyncedItem<Element>)] = SyncEngine.shared.values(under: key).compactMap { itemKey, data in DecodedValues.decode(SyncedItem<Element>.self, from: data).map { (itemKey, $0) } }
        self = items.sorted { ($0.item.position, $0.key) < ($1.item.position, $1.key) }.map(\.item.value)
    }

    /// The same array, which keeps no sync details.
    func attached(to key: String) -> Self {
        self
    }

    /// Keeps each element as its own record under `key/id`, writing only the elements that were added, changed, removed or, when positioned, moved, since a sorted list takes its order from the sort.
    func sync(under key: String, positioned: Bool) {
        let stored: [String: Data] = SyncEngine.shared.values(under: key)
        let keys: [String] = map { "\(key)/\($0.id)" }
        let old: [Double?] = keys.map { stored[$0].flatMap { DecodedValues.decode(SyncedItem<Element>.self, from: $0)?.position } }
        let positions: [Double] = positioned ? SyncEngine.positions(keeping: old) : old.map { $0 ?? 0 }
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var changes: [String: Data?] = Dictionary(uniqueKeysWithValues: Set(stored.keys).subtracting(keys).map { ($0, Data?.none) })
        for (index, element) in enumerated() {
            guard let data: Data = try? encoder.encode(SyncedItem(position: positions[index], value: element)), data != stored[keys[index]] else { continue }
            changes[keys[index]] = data
        }
        if SyncEngine.shared.value(key) == nil { changes[key] = Data("[]".utf8) }
        SyncEngine.shared.write(changes)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SyncedStorage.Collection: SyncedItems {

    /// Reads the items kept under the key in order, reporting that list's sync, or `nil` when none were ever stored.
    init?(syncedUnder key: String) {
        guard let items: [Value] = [Value](syncedUnder: key) else { return nil }
        self.init(items, key: key)
    }

    /// The same items, reporting the sync of the list kept under the key.
    func attached(to key: String) -> Self {
        Self(items, key: key)
    }

    /// Keeps each item as its own record under `key/id`, as an array does.
    func sync(under key: String, positioned: Bool) {
        items.sync(under: key, positioned: positioned)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SyncedStorage.Change: Equatable where Value: Equatable {}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SyncedStorage.Collection: Equatable where Value: Equatable {

    /// Whether the two lists hold the same items in the same order.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items
    }
}

/// How a list synced item by item reads through a filter and sort, and writes back without removing the elements the filter hides.
fileprivate struct SyncedQuery<Value>: Sendable {

    let isSorted: Bool
    let merge: @Sendable (Value) -> Value
    let read: @Sendable (Value) -> Value

    /// Creates the query for the elements kept under the key.
    init<I: Codable & Identifiable & Sendable>(_ key: String, filter: Predicate<I>?, sort descriptors: [SortDescriptor<I>]) where Value: RangeReplaceableCollection, Value.Element == I {
        let shows: @Sendable (I) -> Bool = { element in filter.map { (try? $0.evaluate(element)) ?? false } ?? true }
        self.isSorted = !descriptors.isEmpty
        self.merge = { shown in
            guard filter != nil else { return shown }
            let visible: [I] = Array(shown)
            let kept: Set<I.ID> = Set(visible.map(\.id))
            var remaining: IndexingIterator<[I]> = visible.makeIterator()
            let merged: [I] = ([I](syncedUnder: key) ?? []).filter { !shows($0) || kept.contains($0.id) }.compactMap { shows($0) ? remaining.next() : $0 }
            var result: Value = shown
            result.replaceSubrange(result.startIndex..<result.endIndex, with: merged + Array(remaining))
            return result
        }
        self.read = { items in
            var result: Value = items
            result.replaceSubrange(result.startIndex..<result.endIndex, with: items.filter(shows).sorted(using: descriptors))
            return result
        }
    }
}

/// One element of an array synced item by item, with its position in the array.
fileprivate struct SyncedItem<Element: Codable>: Codable {

    let position: Double
    let value: Element
}

/// A key's value as kept on the device, with its sync status, the code of its last CloudKit failure, and the archived server fields of its record.
fileprivate struct SyncEntry: Codable, Sendable {

    var confirmed: Data?
    var failure: Int?
    var isPending: Bool = false
    var modified: Date?
    var record: Data?
    var status: SyncStatus = .unknown
    var synced: Date?
    var value: Data?

    private enum CodingKeys: CodingKey {

        case confirmed, failure, isPending, modified, record, synced, value
    }
}

/// A folder in the app's Application Support folder that keeps values as JSON files, written in the background so a change never waits on the disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
fileprivate final class DeviceFolder: Sendable {

    private let pending: OSAllocatedUnfairLock<[String: any Encodable & Sendable]> = OSAllocatedUnfairLock(initialState: [:])
    private let queue: DispatchQueue
    private let url: URL

    /// Creates the folder with the name, inside a Composition folder kept apart for each app.
    init(_ name: String) {
        self.queue = DispatchQueue(label: "Composition.\(name)", qos: .utility)
        self.url = URL.applicationSupportDirectory.appending(components: Bundle.main.bundleIdentifier ?? "Composition", "Composition", name, directoryHint: .isDirectory)
    }

    /// The contents of the named file, once any write still waiting finishes, or `nil` when it was never written.
    func read<C: Decodable>(_ type: C.Type, named name: String) -> C? {
        queue.sync {}
        return (try? Data(contentsOf: url.appending(component: "\(name).json"))).flatMap { try? JSONDecoder().decode(C.self, from: $0) }
    }

    /// The contents of every file whose name doesn't start with an underscore, by name.
    func readAll<C: Decodable>(_ type: C.Type) -> [String: C] {
        queue.sync {}
        let names: [String] = (try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasSuffix(".json") && !$0.hasPrefix("_") }.reduce(into: [:]) { contents, file in
            let name: String = String(file.dropLast(5))
            contents[name] = read(C.self, named: name)
        }
    }

    /// Writes the contents to the named file in the background, where newer contents replace any still waiting to be written.
    func write<C: Encodable & Sendable>(_ contents: C, named name: String) {
        let isIdle: Bool = pending.withLock { pending in
            defer { pending[name] = contents }
            return pending.isEmpty
        }
        guard isIdle else { return }
        queue.async { [self] in
            let files: [String: any Encodable & Sendable] = pending.withLock { pending in
                defer { pending = [:] }
                return pending
            }
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for (name, contents) in files {
                guard let data: Data = try? JSONEncoder().encode(contents) else { continue }
                try? data.write(to: url.appending(component: "\(name).json"), options: .atomic)
            }
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
