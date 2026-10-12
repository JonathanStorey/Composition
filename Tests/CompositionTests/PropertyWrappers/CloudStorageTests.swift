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

    @Test func limitViolationAllowsValuesThatFit() {
        #expect(CloudStorage<Int>.limitViolation(writing: Data(count: 1_000), to: "volume", in: [:]) == nil)
    }

    @Test func limitViolationCatchesALongKey() {
        #expect(CloudStorage<Int>.limitViolation(writing: Data(), to: String(repeating: "k", count: 65), in: [:]) != nil)
    }

    @Test func limitViolationCatchesTooManyKeys() {
        let stored: [String: Any] = Dictionary(uniqueKeysWithValues: (0..<1_024).map { ("\($0)", true) })
        #expect(CloudStorage<Int>.limitViolation(writing: Data(), to: "new", in: stored) != nil)
        #expect(CloudStorage<Int>.limitViolation(writing: Data(), to: "0", in: stored) == nil)
    }

    @Test func limitViolationCatchesTooManyBytes() {
        #expect(CloudStorage<Int>.limitViolation(writing: Data(count: 1_048_577), to: "photo", in: [:]) != nil)
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
