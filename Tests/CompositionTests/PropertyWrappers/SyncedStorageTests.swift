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

    #if os(macOS)
    @Test func refreshFailsWithoutTheCloudKitEntitlement() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.projectedValue.refresh()
        #expect(storage.projectedValue.status == .failure(.unavailable))
    }
    #endif

    @Test func statusStartsUnknownForANewKey() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        #expect(storage.projectedValue.status == .unknown)
        #expect(storage.projectedValue.lastSynced == nil)
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

    @Test func bindingWritesThrough() {
        let storage: SyncedStorage<Bool> = SyncedStorage(wrappedValue: false, UUID().uuidString)
        storage.projectedValue.binding.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
