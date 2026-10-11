// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorageTests.swift
// dependencies: [PropertyWrappers/SyncedStorage.swift]

// MARK: - Foundation

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct SyncStatusTests {

    @Test func statusSurvivesEncoding() throws {
        let status: SyncStatus = .failure(.quotaExceeded)
        #expect(try JSONDecoder().decode(SyncStatus.self, from: JSONEncoder().encode(status)) == status)
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Observation

@Suite struct SyncedStorageTests {

    @Test func initDefaultsToLatestConflict() {
        #expect(SyncedStorage<String?>("theme").conflict == .latest)
    }

    @Test func initTakesConflictAsSecondArgument() {
        #expect(SyncedStorage<String?>("theme", .first).conflict == .first)
    }

    @Test func prefersLocalOnlyWhenTheWriteIsNewer() {
        let earlier: Date = Date(timeIntervalSince1970: 1_000)
        let later: Date = Date(timeIntervalSince1970: 2_000)
        #expect(SyncEngine.prefersLocal(written: later, over: earlier, keepsFirst: false))
        #expect(!SyncEngine.prefersLocal(written: earlier, over: later, keepsFirst: false))
        #expect(SyncEngine.prefersLocal(written: earlier, over: nil, keepsFirst: false))
    }

    @Test func prefersServerOnATieOrWhenKeepingTheFirst() {
        let date: Date = Date(timeIntervalSince1970: 1_000)
        #expect(!SyncEngine.prefersLocal(written: date, over: date, keepsFirst: false))
        #expect(!SyncEngine.prefersLocal(written: date.addingTimeInterval(1), over: date, keepsFirst: true))
        #expect(!SyncEngine.prefersLocal(written: nil, over: nil, keepsFirst: false))
    }

    #if os(macOS)
    @Test func refreshFailsWithoutTheCloudKitEntitlement() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.refresh()
        #expect(storage.status == .failure(.unavailable))
    }
    #endif

    @Test func statusStartsUnknownForANewKey() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        #expect(storage.status == .unknown)
        #expect(storage.lastSynced == nil)
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
