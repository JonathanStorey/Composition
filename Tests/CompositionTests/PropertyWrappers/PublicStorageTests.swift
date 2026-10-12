// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/PublicStorageTests.swift
// dependencies: [PropertyWrappers/PublicStorage.swift]

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct PublicStorageTests {

    @Test func entryChangeNotifiesObservers() async {
        let storage: PublicStorage<Bool> = PublicStorage(UUID().uuidString)
        await confirmation { changed in
            withObservationTracking({ _ = storage.wrappedValue }, onChange: { changed() })
            storage.entry = true
        }
        storage.entry = nil
    }

    @Test func entryAppearsBeforeItSyncs() {
        let storage: PublicStorage<[String]> = PublicStorage(UUID().uuidString)
        storage.entry = ["Dune", "Emma"]
        #expect(storage.entry == ["Dune", "Emma"])
        #expect(storage.wrappedValue == [["Dune", "Emma"]])
        storage.entry = nil
    }

    @Test func entrySetToNilRemovesIt() {
        let storage: PublicStorage<Bool> = PublicStorage(UUID().uuidString)
        storage.entry = true
        storage.entry = nil
        #expect(storage.entry == nil)
        #expect(storage.wrappedValue.isEmpty)
    }

    @Test func sortedStorageReadsTheUsersEntry() {
        let storage: PublicStorage<Int> = PublicStorage(UUID().uuidString, sort: \.self, order: .reverse)
        storage.entry = 5
        #expect(storage.wrappedValue == [5])
        storage.entry = nil
        #expect(storage.wrappedValue.isEmpty)
    }

    @Test func wrappedValueIsEmptyForANewKey() {
        let storage: PublicStorage<Int> = PublicStorage(UUID().uuidString)
        #expect(storage.wrappedValue.isEmpty)
        #expect(storage.entry == nil)
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

extension PublicStorageTests {

    @Test func projectedValueWritesTheUsersEntry() {
        let storage: PublicStorage<Bool> = PublicStorage(UUID().uuidString)
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue == [true])
        storage.projectedValue.wrappedValue = nil
        #expect(storage.projectedValue.wrappedValue == nil)
    }
}
#endif
