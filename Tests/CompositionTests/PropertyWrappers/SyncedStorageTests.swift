// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/SyncedStorageTests.swift
// dependencies: [PropertyWrappers/SyncedStorage.swift]

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import CloudKit
import Foundation
import Observation
import Testing
@testable import Composition

/// A to-do item, identifiable so SyncedStorage keeps each one as its own record.
private struct Todo: Codable, Equatable, Identifiable, Sendable {

    let id: Int
    var title: String
    var due: Date? = nil
}

@Suite struct SyncedStorageTests {

    @Test func arrayOfIdentifiableElementsIsDefaultUntilWritten() {
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [Todo(id: 1, title: "Read")], UUID().uuidString)
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read")])
        storage.wrappedValue = []
        #expect(storage.wrappedValue.isEmpty)
    }

    @Test func arrayOfIdentifiableElementsKeepsEachElementAsItsOwnEntry() {
        let key: String = UUID().uuidString
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], key)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")])
        #expect(SyncEngine.shared.values(under: key).keys.sorted() == ["\(key)/1", "\(key)/2"])
        storage.wrappedValue = [Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue == [Todo(id: 2, title: "Write")])
        #expect(SyncEngine.shared.value("\(key)/1") == nil)
    }

    @Test func arrayOfIdentifiableElementsKeepsItsOrder() {
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], UUID().uuidString)
        let todos: [Todo] = (1...4).map { Todo(id: $0, title: "\($0)") }
        storage.wrappedValue = todos
        storage.wrappedValue = [todos[3], todos[0], todos[2], todos[1]]
        #expect(storage.wrappedValue.map(\.id) == [4, 1, 3, 2])
    }

    @Test func arrayOfIdentifiableElementsRewritesOnlyChangedElements() {
        let key: String = UUID().uuidString
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], key)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        let untouched: Data? = SyncEngine.shared.value("\(key)/1")
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Edit")]
        #expect(SyncEngine.shared.value("\(key)/1") == untouched)
    }

    @Test func arrayWithAFilterKeepsHiddenElementsInPlace() {
        let key: String = UUID().uuidString
        let all: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], key)
        let open: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], key, filter: #Predicate<Todo> { $0.due == nil })
        all.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write", due: .distantFuture), Todo(id: 3, title: "Edit")]
        open.wrappedValue = [Todo(id: 3, title: "Edit"), Todo(id: 4, title: "Print")]
        #expect(all.wrappedValue.map(\.id) == [2, 3, 4])
    }

    @Test func arrayWithAFilterReadsOnlyMatchingElements() {
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], UUID().uuidString, filter: #Predicate<Todo> { $0.due == nil }, sort: \.title)
        storage.wrappedValue = [Todo(id: 1, title: "Write"), Todo(id: 2, title: "Edit", due: .distantFuture), Todo(id: 3, title: "Read")]
        #expect(storage.wrappedValue.map(\.id) == [3, 1])
    }

    @Test func arrayWithASortKeepsPositionsWhenReordered() {
        let key: String = UUID().uuidString
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], key, sort: \.title)
        storage.wrappedValue = [Todo(id: 1, title: "Write"), Todo(id: 2, title: "Read")]
        let stored: [String: Data] = SyncEngine.shared.values(under: key)
        storage.wrappedValue = [Todo(id: 2, title: "Read"), Todo(id: 1, title: "Write")]
        #expect(SyncEngine.shared.values(under: key) == stored)
    }

    @Test func arrayWithASortReadsSorted() {
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], UUID().uuidString, sort: \.title, order: .reverse)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue.map(\.id) == [2, 1])
    }

    @Test func arrayWithAnOptionalSortPutsNilFirst() {
        let storage: SyncedStorage<[Todo]> = SyncedStorage(wrappedValue: [], UUID().uuidString, sort: \.due)
        storage.wrappedValue = [Todo(id: 1, title: "Read", due: .distantFuture), Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue.map(\.id) == [2, 1])
    }

    @Test func collectionModifiedIsTheWriteTimeOrNilWhenNotKept() {
        let storage: SyncedStorage<SyncedStorage<Todo>.Collection> = SyncedStorage(wrappedValue: [], UUID().uuidString)
        let before: Date = .now
        storage.wrappedValue = [Todo(id: 1, title: "Read")]
        #expect(storage.wrappedValue.modified(Todo(id: 1, title: "Read")).map { $0 >= before } == true)
        #expect(storage.wrappedValue.modified(Todo(id: 2, title: "Write")) == nil)
    }

    #if os(macOS)
    @Test func collectionRefreshThrowsWithoutTheCloudKitEntitlement() async {
        let storage: SyncedStorage<SyncedStorage<Todo>.Collection> = SyncedStorage(wrappedValue: [], UUID().uuidString)
        await #expect(throws: CKError.self) { try await storage.wrappedValue.refresh() }
        guard case .failure = storage.wrappedValue.status else { Issue.record("Expected a failure"); return }
    }
    #endif

    @Test func collectionStartsUnknownWithNothingPendingOrFailed() {
        let todos: SyncedStorage<Todo>.Collection = SyncedStorage<SyncedStorage<Todo>.Collection>(wrappedValue: [], UUID().uuidString).wrappedValue
        guard case .unknown = todos.status else { Issue.record("Expected unknown"); return }
        #expect(todos.pending.isEmpty)
        #expect(todos.failed.isEmpty)
    }

    @Test func collectionWithAFilterReadsOnlyMatchingItems() {
        let storage: SyncedStorage<SyncedStorage<Todo>.Collection> = SyncedStorage(wrappedValue: [], UUID().uuidString, filter: #Predicate<Todo> { $0.due == nil }, sort: \.title)
        storage.wrappedValue = [Todo(id: 1, title: "Write"), Todo(id: 2, title: "Edit", due: .distantFuture), Todo(id: 3, title: "Read")]
        #expect(storage.wrappedValue.map(\.id) == [3, 1])
    }

    @Test func collectionWorksLikeAnArray() {
        let storage: SyncedStorage<SyncedStorage<Todo>.Collection> = SyncedStorage(wrappedValue: [], UUID().uuidString)
        storage.wrappedValue.append(Todo(id: 1, title: "Read"))
        storage.wrappedValue.append(Todo(id: 2, title: "Write"))
        storage.wrappedValue[0].title = "Edit"
        storage.wrappedValue.removeAll { $0.id == 2 }
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Edit")])
    }

    #if compiler(>=6.2) && os(macOS)
    @Test func keyWithASlashOrLeadingUnderscoreStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, "todos/1") }
        await #expect(processExitsWith: .failure) { _ = SyncedStorage<Int>(wrappedValue: 0, "_todos") }
    }
    #endif

    @Test func positionsKeepItemsStillInOrder() {
        #expect(SyncEngine.positions(keeping: [0, 1, 2]) == [0, 1, 2])
        #expect(SyncEngine.positions(keeping: [2, 0, 1]) == [-1, 0, 1])
    }

    @Test func positionsPlaceNewItemsBetweenTheirNeighbors() {
        #expect(SyncEngine.positions(keeping: [0, nil, 1]) == [0, 0.5, 1])
        #expect(SyncEngine.positions(keeping: [nil, 0, 1, nil]) == [-1, 0, 1, 2])
        #expect(SyncEngine.positions(keeping: [nil, nil]) == [0, 1])
    }

    @Test func prefersLocalOnlyWhenTheWriteIsNewer() {
        let earlier: Date = Date(timeIntervalSince1970: 1_000)
        let later: Date = Date(timeIntervalSince1970: 2_000)
        #expect(SyncEngine.prefersLocal(written: later, over: earlier))
        #expect(!SyncEngine.prefersLocal(written: earlier, over: later))
        #expect(SyncEngine.prefersLocal(written: earlier, over: nil))
    }

    @Test func prefersServerOnATie() {
        let date: Date = Date(timeIntervalSince1970: 1_000)
        #expect(!SyncEngine.prefersLocal(written: date, over: date))
        #expect(!SyncEngine.prefersLocal(written: nil, over: nil))
    }

    @Test func recordViolationAllowsAnOrdinaryKeyAndValue() {
        #expect(SyncEngine.recordViolation(named: "todos/1", holding: Data(count: 1_000)) == nil)
        #expect(SyncEngine.recordViolation(named: "todos", holding: nil) == nil)
    }

    @Test func recordViolationCatchesAValueOver1MB() {
        #expect(SyncEngine.recordViolation(named: "photo", holding: Data(count: 1_000_000)) != nil)
    }

    @Test func recordViolationCatchesKeysCloudKitRejects() {
        #expect(SyncEngine.recordViolation(named: "_todos", holding: nil) != nil)
        #expect(SyncEngine.recordViolation(named: "tâches", holding: nil) != nil)
        #expect(SyncEngine.recordViolation(named: String(repeating: "k", count: 256), holding: nil) != nil)
    }

    #if os(macOS)
    @Test func refreshFailsWithoutTheCloudKitEntitlement() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.refresh()
        guard case .failure(let error) = storage.status else { Issue.record("Expected a failure"); return }
        #expect((error as? CKError)?.code == .missingEntitlement)
    }
    #endif

    @Test func statusStartsUnknownForANewKey() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        guard case .unknown = storage.status else { Issue.record("Expected unknown"); return }
        #expect(storage.lastSynced == nil)
    }

    @Test func syncedValueIgnoresWritesUntilTheyReachICloud() {
        let storage: SyncedStorage<Int> = SyncedStorage(wrappedValue: 0, UUID().uuidString)
        storage.wrappedValue = 5
        #expect(storage.wrappedValue == 5)
        #expect(storage.syncedValue == 0)
    }

    @Test func wrappedValueChangeLeavesStatusUnknown() {
        let storage: SyncedStorage<Int?> = SyncedStorage(UUID().uuidString)
        storage.wrappedValue = 3
        guard case .unknown = storage.status else { Issue.record("Expected unknown"); return }
        storage.wrappedValue = nil
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
