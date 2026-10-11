// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/KeychainStorageTests.swift
// dependencies: [PropertyWrappers/KeychainStorage.swift]

#if canImport(Foundation) && canImport(Security)
import Foundation
import Testing
@testable import Composition

@Suite struct KeychainStorageTests {

    @Test func initDefaultsToLocal() {
        #expect(KeychainStorage<String>("token").location == .local)
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
