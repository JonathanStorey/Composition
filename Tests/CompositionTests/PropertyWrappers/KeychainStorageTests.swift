// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/KeychainStorageTests.swift
// dependencies: [PropertyWrappers/KeychainStorage.swift]

#if canImport(Foundation) && canImport(Observation) && canImport(Security)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct KeychainStorageTests {

    @Test func initDefaultsToLocal() {
        #expect(KeychainStorage<String>("token").location == .local)
    }

    @Test func wrappedValueChangeIgnoresOtherKeys() async {
        let reader: KeychainStorage<Int> = KeychainStorage(UUID().uuidString, service: "CompositionTests")
        let writer: KeychainStorage<Int> = KeychainStorage(UUID().uuidString, service: "CompositionTests")
        await confirmation(expectedCount: 0) { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        writer.wrappedValue = nil
    }

    @Test func wrappedValueChangeNotifiesOtherWrappersForTheSameKey() async {
        let key: String = UUID().uuidString
        let reader: KeychainStorage<Int> = KeychainStorage(key, service: "CompositionTests")
        let writer: KeychainStorage<Int> = KeychainStorage(key, service: "CompositionTests")
        await confirmation { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        #expect(reader.wrappedValue == 1)
        writer.wrappedValue = nil
    }

    @Test func wrappedValueIsNilWhenNothingIsStored() {
        #expect(KeychainStorage<String>(UUID().uuidString, service: "CompositionTests").wrappedValue == nil)
    }

    @Test func wrappedValueOverwritesStoredValue() {
        let storage: KeychainStorage<Int> = KeychainStorage(UUID().uuidString, service: "CompositionTests")
        storage.wrappedValue = 1
        storage.wrappedValue = 2
        #expect(storage.wrappedValue == 2)
        storage.wrappedValue = nil
    }

    @Test func wrappedValueStoresReadsAndRemovesValue() {
        let storage: KeychainStorage<UUID> = KeychainStorage(UUID().uuidString, service: "CompositionTests")
        let identifier: UUID = UUID()
        storage.wrappedValue = identifier
        #expect(storage.wrappedValue == identifier)
        storage.wrappedValue = nil
        #expect(storage.wrappedValue == nil)
    }
}
#endif
