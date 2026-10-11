// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/CloudStorageTests.swift
// dependencies: [PropertyWrappers/CloudStorage.swift]

// MARK: - Foundation + Observation

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct CloudStorageTests {

    /// Whether this process can write to iCloud key-value storage.
    private static let canStore: Bool = {
        let key: String = UUID().uuidString
        NSUbiquitousKeyValueStore.default.set(true, forKey: key)
        defer { NSUbiquitousKeyValueStore.default.removeObject(forKey: key) }
        return NSUbiquitousKeyValueStore.default.bool(forKey: key)
    }()

    @Test func initWithoutDefaultStartsNil() {
        #expect(CloudStorage<String?>(UUID().uuidString).wrappedValue == nil)
    }

    @Test func wrappedValueChangeNotifiesOtherWrappersForTheSameKey() async {
        let key: String = UUID().uuidString
        let reader: CloudStorage<Int?> = CloudStorage(key)
        let writer: CloudStorage<Int?> = CloudStorage(key)
        await confirmation { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        writer.wrappedValue = nil
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        #expect(CloudStorage(wrappedValue: 7, UUID().uuidString).wrappedValue == 7)
    }

    @Test(.enabled(if: CloudStorageTests.canStore, "Needs the iCloud key-value storage entitlement, which test runners lack")) func wrappedValueStoresReadsAndRemovesValue() {
        let storage: CloudStorage<String?> = CloudStorage(UUID().uuidString)
        storage.wrappedValue = "Dune"
        #expect(storage.wrappedValue == "Dune")
        storage.wrappedValue = nil
        #expect(storage.wrappedValue == nil)
    }
}
#endif
