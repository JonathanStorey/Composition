// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/EncryptedStorageTests.swift
// dependencies: [PropertyWrappers/EncryptedStorage.swift]

// MARK: - Foundation + Observation + Security

#if canImport(Foundation) && canImport(Observation) && canImport(Security)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct EncryptedStorageTests {

    @Test func keychainStorageIsEncryptedStorage() {
        let storage: EncryptedStorage<Int> = KeychainStorage(wrappedValue: 3, UUID().uuidString, .thisDevice, service: "CompositionTests")
        #expect(storage.wrappedValue == 3)
    }

    @Test func wrappedValueChangeIgnoresOtherKeys() async {
        let reader: EncryptedStorage<Int?> = EncryptedStorage(UUID().uuidString, .thisDevice, service: "CompositionTests")
        let writer: EncryptedStorage<Int?> = EncryptedStorage(UUID().uuidString, .thisDevice, service: "CompositionTests")
        await confirmation(expectedCount: 0) { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        writer.wrappedValue = nil
    }

    @Test func wrappedValueChangeNotifiesOtherWrappersForTheSameKey() async {
        let key: String = UUID().uuidString
        let reader: EncryptedStorage<Int?> = EncryptedStorage(key, .thisDevice, service: "CompositionTests")
        let writer: EncryptedStorage<Int?> = EncryptedStorage(key, .thisDevice, service: "CompositionTests")
        await confirmation { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        #expect(reader.wrappedValue == 1)
        writer.wrappedValue = nil
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        let storage: EncryptedStorage<Int> = EncryptedStorage(wrappedValue: 7, UUID().uuidString, .thisDevice, service: "CompositionTests")
        #expect(storage.wrappedValue == 7)
        storage.wrappedValue = 8
        #expect(storage.wrappedValue == 8)
    }

    @Test func wrappedValueIsNilWhenNothingIsStored() {
        #expect(EncryptedStorage<String?>(UUID().uuidString, .thisDevice, service: "CompositionTests").wrappedValue == nil)
    }

    @Test func wrappedValueOverwritesStoredValue() {
        let storage: EncryptedStorage<Int?> = EncryptedStorage(UUID().uuidString, .thisDevice, service: "CompositionTests")
        storage.wrappedValue = 1
        storage.wrappedValue = 2
        #expect(storage.wrappedValue == 2)
        storage.wrappedValue = nil
    }

    @Test func wrappedValueStoresReadsAndRemovesValue() {
        let storage: EncryptedStorage<UUID?> = EncryptedStorage(UUID().uuidString, .thisDevice, service: "CompositionTests")
        let identifier: UUID = UUID()
        storage.wrappedValue = identifier
        #expect(storage.wrappedValue == identifier)
        storage.wrappedValue = nil
        #expect(storage.wrappedValue == nil)
    }
}
#endif

// MARK: - Foundation + Observation + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

extension EncryptedStorageTests {

    @Test func projectedValueWritesThrough() {
        let storage: EncryptedStorage<Bool> = EncryptedStorage(wrappedValue: false, UUID().uuidString, .thisDevice, service: "CompositionTests")
        storage.projectedValue.wrappedValue = true
        #expect(storage.wrappedValue)
    }
}
#endif
