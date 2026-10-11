// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageChangesTests.swift
// dependencies: [PropertyWrappers/StorageChanges.swift]

// MARK: - Foundation + Observation

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation
import Testing
@testable import Composition

@Suite struct StorageChangesTests {

    @Test func postNotifiesOnlyTheSameItem() async {
        let reader: StorageChanges = StorageChanges(item: [UUID().uuidString])
        let writer: StorageChanges = StorageChanges(item: [UUID().uuidString])
        await confirmation(expectedCount: 0) { changed in
            withObservationTracking({ reader.track() }, onChange: { changed() })
            writer.post()
        }
    }

    @Test func postNotifiesTheSameItem() async {
        let item: [String] = [UUID().uuidString]
        let reader: StorageChanges = StorageChanges(item: item)
        let writer: StorageChanges = StorageChanges(item: item)
        await confirmation { changed in
            withObservationTracking({ reader.track() }, onChange: { changed() })
            writer.post()
        }
    }
}
#endif

// MARK: - Darwin + Foundation + Observation

#if canImport(Darwin) && canImport(Foundation) && canImport(Observation)
import Darwin

extension StorageChangesTests {

    @Test(.timeLimit(.minutes(1))) func processNotificationNotifiesWhenWatchingAcrossProcesses() async {
        let item: [String] = [UUID().uuidString]
        let changes: StorageChanges = StorageChanges(item: item, acrossProcesses: true)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            withObservationTracking({ changes.track() }, onChange: { continuation.resume() })
            notify_post(StorageChanges.processName(for: item))
        }
    }
}
#endif
