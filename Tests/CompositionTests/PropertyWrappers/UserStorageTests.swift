// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/UserStorageTests.swift
// dependencies: [PropertyWrappers/UserStorage.swift]

// MARK: - Foundation + Observation

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation
import Testing
@testable import Composition

@Observable
private final class Settings {

    @ObservationIgnored @UserStorage("CompositionTests.Settings.volume") var volume: Int = 5
}

@Suite struct UserStorageTests {

    @Test func appGroupStoreWritesToItsSuite() {
        let storage: UserStorage<String?> = UserStorage(UUID().uuidString, .appGroup("group.CompositionTests"))
        storage.wrappedValue = "Dune"
        #expect(UserDefaults(suiteName: "group.CompositionTests")?.string(forKey: storage.key) == "Dune")
        #expect(UserDefaults.standard.string(forKey: storage.key) == nil)
        storage.wrappedValue = nil
    }

    @Test func initDefaultsToStandardStore() {
        #expect(UserStorage<String?>("volume").store == .standard)
    }

    @Test func initWithoutDefaultStartsNil() {
        #expect(UserStorage<String?>(UUID().uuidString).wrappedValue == nil)
    }

    @Test func observableClassReadsAndRefreshesThroughWrapper() async {
        let settings: Settings = Settings()
        await confirmation { changed in
            withObservationTracking({ _ = settings.volume }, onChange: { changed() })
            UserDefaults.standard.set(9, forKey: "CompositionTests.Settings.volume")
        }
        #expect(settings.volume == 9)
        UserDefaults.standard.removeObject(forKey: "CompositionTests.Settings.volume")
    }

    @Test func userDefaultsStorageIsUserStorage() {
        let storage: UserStorage<Int> = UserDefaultsStorage(wrappedValue: 3, UUID().uuidString)
        #expect(storage.wrappedValue == 3)
    }

    @Test func wrappedValueChangeNotifiesOtherWrappersForTheSameKey() async {
        let key: String = UUID().uuidString
        let reader: UserStorage<Int?> = UserStorage(key)
        let writer: UserStorage<Int?> = UserStorage(key)
        await confirmation { changed in
            withObservationTracking({ _ = reader.wrappedValue }, onChange: { changed() })
            writer.wrappedValue = 1
        }
        #expect(reader.wrappedValue == 1)
        writer.wrappedValue = nil
    }

    @Test func wrappedValueIsDefaultWhenNothingIsStored() {
        #expect(UserStorage(wrappedValue: 7, UUID().uuidString).wrappedValue == 7)
    }

    @Test func wrappedValueStoresCodableValuesAsJSON() {
        let storage: UserStorage<[String]?> = UserStorage(UUID().uuidString)
        storage.wrappedValue = ["Dune", "Emma"]
        #expect(storage.wrappedValue == ["Dune", "Emma"])
        #expect(UserDefaults.standard.object(forKey: storage.key) is Data)
        storage.wrappedValue = nil
        #expect(UserDefaults.standard.object(forKey: storage.key) == nil)
    }

    @Test func wrappedValueStoresPropertyListValuesAsIs() {
        let storage: UserStorage<String?> = UserStorage(UUID().uuidString)
        storage.wrappedValue = "Dune"
        #expect(UserDefaults.standard.string(forKey: storage.key) == "Dune")
        storage.wrappedValue = nil
    }
}
#endif

// MARK: - Foundation + Observation + SwiftData

#if canImport(Foundation) && canImport(Observation) && canImport(SwiftData)
import SwiftData

@Model
private final class Preferences {

    @Transient @UserStorage("CompositionTests.Preferences.volume") var volume: Int = 5

    init() {}
}

extension UserStorageTests {

    @Test func modelReadsAndWritesThroughTransientWrapper() {
        let preferences: Preferences = Preferences()
        preferences.volume = 9
        #expect(UserDefaults.standard.integer(forKey: "CompositionTests.Preferences.volume") == 9)
        UserDefaults.standard.removeObject(forKey: "CompositionTests.Preferences.volume")
    }
}
#endif

// MARK: - Foundation + Observation + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(SwiftUI)
import SwiftUI

extension UserStorageTests {

    @Test func projectedValueWritesThroughToUserDefaults() {
        let storage: UserStorage<Bool> = UserStorage(wrappedValue: false, UUID().uuidString)
        storage.projectedValue.wrappedValue = true
        #expect(UserDefaults.standard.bool(forKey: storage.key))
        UserDefaults.standard.removeObject(forKey: storage.key)
    }
}
#endif
