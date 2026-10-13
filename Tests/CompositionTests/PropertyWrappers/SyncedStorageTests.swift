// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorageTests.swift
// dependencies: [PropertyWrappers/FileStorage.swift, PropertyWrappers/SyncedStorage.swift]

// MARK: - CloudKit + Foundation + Observation + os + Security + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(UniformTypeIdentifiers)
import CloudKit
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct SyncedStorageTests {

    #if compiler(>=6.2) && os(macOS)
    @Test func keyThatCantNameARecordOrFileStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, "todos/1") }
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, "_todos") }
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, ".todos") }
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, "") }
    }
    #endif

    @Test func prefersLocalOnlyWhenTheWriteIsNewer() {
        let earlier: Date = Date(timeIntervalSince1970: 1_000)
        let later: Date = Date(timeIntervalSince1970: 2_000)
        #expect(SyncEngine.prefersLocal(written: later, over: earlier))
        #expect(!SyncEngine.prefersLocal(written: earlier, over: later))
        #expect(SyncEngine.prefersLocal(written: earlier, over: nil))
    }

    @Test func prefersServerOnATie() {
        let date: Date = Date(timeIntervalSince1970: 1_000)
        #expect(!SyncEngine.prefersLocal(written: date, over: date))
        #expect(!SyncEngine.prefersLocal(written: nil, over: nil))
    }

    @Test func recordViolationAllowsAnOrdinaryKeyAndValue() {
        #expect(SyncEngine.recordViolation(named: "todos/1", holding: Data(count: 1_000)) == nil)
        #expect(SyncEngine.recordViolation(named: "todos", holding: nil) == nil)
    }

    @Test func recordViolationCatchesAValueOver1MB() {
        #expect(SyncEngine.recordViolation(named: "photo", holding: Data(count: 1_000_000)) != nil)
    }

    @Test func recordViolationCatchesKeysCloudKitRejects() {
        #expect(SyncEngine.recordViolation(named: "_todos", holding: nil) != nil)
        #expect(SyncEngine.recordViolation(named: "tâches", holding: nil) != nil)
        #expect(SyncEngine.recordViolation(named: String(repeating: "k", count: 256), holding: nil) != nil)
    }

    #if os(macOS)
    @Test func refreshFailsWithoutTheCloudKitEntitlement() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.refresh()
        guard case .failure(let error) = storage.status else { Issue.record("Expected a failure"); return }
        #expect((error as? CKError)?.code == .missingEntitlement)
    }
    #endif

    @Test func statusStartsUnknownForANewKey() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        guard case .unknown = storage.status else { Issue.record("Expected unknown"); return }
        #expect(storage.lastSynced == nil)
    }

    @Test func syncedValueIgnoresWritesUntilTheyReachICloud() {
        let storage: SyncedStorage<Int> = SyncedStorage(wrappedValue: 0, UUID().uuidString)
        storage.wrappedValue = 5
        #expect(storage.wrappedValue == 5)
        #expect(storage.syncedValue == 0)
    }

    @Test func wrappedValueChangeLeavesStatusUnknown() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.wrappedValue = 3
        guard case .unknown = storage.status else { Issue.record("Expected unknown"); return }
        storage.wrappedValue = nil
    }

    @Test func wrappedValueChangeNotifiesObservers() async {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        await confirmation { changed in
            withObservationTracking({ _ = storage.wrappedValue }, onChange: { changed() })
            storage.wrappedValue = 1
        }
        storage.wrappedValue = nil
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        #expect(SyncedStorage(wrappedValue: 7, UUID().uuidString).wrappedValue == 7)
    }

    @Test func wrappedValueKeepsAFileForTheKeyInTheAppFolder() {
        let key: String = UUID().uuidString
        let storage: SyncedStorage<Int?> = SyncedStorage(key)
        storage.wrappedValue = 4
        StoredFile.flushAll()
        #expect(FileManager.default.fileExists(atPath: StoredFile.appFolder.appending(components: "Composition", "SyncedStorage", "\(key).json").path(percentEncoded: false)))
        storage.wrappedValue = nil
    }

    @Test func wrappedValueKeepsValuesOnTheDevice() {
        let storage: SyncedStorage<[String]?> = SyncedStorage(UUID().uuidString)
        storage.wrappedValue = ["Dune", "Emma"]
        #expect(storage.wrappedValue == ["Dune", "Emma"])
        storage.wrappedValue = nil
        #expect(storage.wrappedValue == nil)
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

extension SyncedStorageTests {

    @Test func projectedValueWritesThrough() {
        let storage: SyncedStorage<Bool> = SyncedStorage(wrappedValue: false, UUID().uuidString)
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
