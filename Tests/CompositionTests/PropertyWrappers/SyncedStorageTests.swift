// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorageTests.swift
// dependencies: [PropertyWrappers/SyncedStorage.swift]

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import CloudKit
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct SyncedStorageTests {

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

    @Test func wrappedValueKeepsValuesOnTheDevice() {
        let storage: SyncedStorage<[String]?> = SyncedStorage(UUID().uuidString)
        storage.wrappedValue = ["Dune", "Emma"]
        #expect(storage.wrappedValue == ["Dune", "Emma"])
        storage.wrappedValue = nil
        #expect(storage.wrappedValue == nil)
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

extension SyncedStorageTests {

    @Test func projectedValueWritesThrough() {
        let storage: SyncedStorage<Bool> = SyncedStorage(wrappedValue: false, UUID().uuidString)
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
