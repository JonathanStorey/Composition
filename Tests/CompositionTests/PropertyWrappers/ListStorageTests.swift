// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/ListStorageTests.swift
// dependencies: [PropertyWrappers/ListStorage.swift, PropertyWrappers/SyncedStorage.swift]

// MARK: - CloudKit + Foundation + Observation + os + Security + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(UniformTypeIdentifiers)
import CloudKit
import Foundation
import Testing
@testable import Composition

/// A to-do item, identifiable so ListStorage keeps each one as its own record.
private struct Todo: Codable, Equatable, Identifiable, Sendable {

    let id: Int
    var title: String
    var due: Date? = nil
}

@Suite struct ListStorageTests {

    @Test func filterKeepsHiddenItemsInPlace() {
        let key: String = UUID().uuidString
        let all: ListStorage<Todo> = ListStorage(key)
        let open: ListStorage<Todo> = ListStorage(key, filter: #Predicate<Todo> { $0.due == nil })
        all.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write", due: .distantFuture), Todo(id: 3, title: "Edit")]
        open.wrappedValue = [Todo(id: 3, title: "Edit"), Todo(id: 4, title: "Print")]
        #expect(all.wrappedValue.map(\.id) == [2, 3, 4])
    }

    @Test func filterReadsOnlyMatchingItems() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString, filter: #Predicate<Todo> { $0.due == nil }, sort: \.title)
        storage.wrappedValue = [Todo(id: 1, title: "Write"), Todo(id: 2, title: "Edit", due: .distantFuture), Todo(id: 3, title: "Read")]
        #expect(storage.wrappedValue.map(\.id) == [3, 1])
    }

    @Test func identifiedStorageIsListStorage() {
        let storage: ListStorage<Todo> = IdentifiedStorage(UUID().uuidString)
        storage.wrappedValue = [Todo(id: 1, title: "Read")]
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read")])
    }

    #if compiler(>=6.2) && os(macOS)
    @Test func keyThatCantNameARecordOrFileStopsTheApp() async {
        await #expect(processExitsWith: .failure) { _ = ListStorage<Todo>("todos/1") }
        await #expect(processExitsWith: .failure) { _ = ListStorage<Todo>("_todos") }
        await #expect(processExitsWith: .failure) { _ = ListStorage<Todo>(".todos") }
        await #expect(processExitsWith: .failure) { _ = ListStorage<Todo>("") }
    }
    #endif

    @Test func modifiedIsTheWriteTimeOrNilWhenNotKept() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        let before: Date = .now
        storage.wrappedValue = [Todo(id: 1, title: "Read")]
        #expect(storage.modified(Todo(id: 1, title: "Read")).map { $0 >= before } == true)
        #expect(storage.modified(Todo(id: 2, title: "Write")) == nil)
    }

    @Test func optionalSortPutsNilFirst() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString, sort: \.due)
        storage.wrappedValue = [Todo(id: 1, title: "Read", due: .distantFuture), Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue.map(\.id) == [2, 1])
    }

    @Test func positionsKeepItemsStillInOrder() {
        #expect(SyncEngine.positions(keeping: [0, 1, 2]) == [0, 1, 2])
        #expect(SyncEngine.positions(keeping: [2, 0, 1]) == [-1, 0, 1])
    }

    @Test func positionsPlaceNewItemsBetweenTheirNeighbors() {
        #expect(SyncEngine.positions(keeping: [0, nil, 1]) == [0, 0.5, 1])
        #expect(SyncEngine.positions(keeping: [nil, 0, 1, nil]) == [-1, 0, 1, 2])
        #expect(SyncEngine.positions(keeping: [nil, nil]) == [0, 1])
    }

    #if os(macOS)
    @Test func refreshThrowsWithoutTheCloudKitEntitlement() async {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        await #expect(throws: CKError.self) { try await storage.refresh() }
        guard case .failure = storage.status else { Issue.record("Expected a failure"); return }
    }
    #endif

    @Test func sortKeepsPositionsWhenReordered() {
        let key: String = UUID().uuidString
        let storage: ListStorage<Todo> = ListStorage(key, sort: \.title)
        storage.wrappedValue = [Todo(id: 1, title: "Write"), Todo(id: 2, title: "Read")]
        let stored: [String: Data] = SyncEngine.shared.values(under: key)
        storage.wrappedValue = [Todo(id: 2, title: "Read"), Todo(id: 1, title: "Write")]
        #expect(SyncEngine.shared.values(under: key) == stored)
    }

    @Test func sortReadsSorted() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString, sort: \.title, order: .reverse)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue.map(\.id) == [2, 1])
    }

    @Test func statusStartsUnknownWithNothingPending() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        guard case .unknown = storage.status else { Issue.record("Expected unknown"); return }
        #expect(storage.pending.isEmpty)
    }

    @Test func wrappedValueIsEmptyUntilWritten() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        #expect(storage.wrappedValue.isEmpty)
        storage.wrappedValue = [Todo(id: 1, title: "Read")]
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read")])
    }

    @Test func wrappedValueKeepsEachItemAsItsOwnEntry() {
        let key: String = UUID().uuidString
        let storage: ListStorage<Todo> = ListStorage(key)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        #expect(SyncEngine.shared.values(under: key).keys.sorted() == ["\(key)/1", "\(key)/2"])
        storage.wrappedValue = [Todo(id: 2, title: "Write")]
        #expect(storage.wrappedValue == [Todo(id: 2, title: "Write")])
        #expect(SyncEngine.shared.value("\(key)/1") == nil)
    }

    @Test func wrappedValueKeepsItsOrder() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        let todos: [Todo] = (1...4).map { Todo(id: $0, title: "\($0)") }
        storage.wrappedValue = todos
        storage.wrappedValue = [todos[3], todos[0], todos[2], todos[1]]
        #expect(storage.wrappedValue.map(\.id) == [4, 1, 3, 2])
    }

    @Test func wrappedValueRewritesOnlyChangedItems() {
        let key: String = UUID().uuidString
        let storage: ListStorage<Todo> = ListStorage(key)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        let untouched: Data? = SyncEngine.shared.value("\(key)/1")
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Edit")]
        #expect(SyncEngine.shared.value("\(key)/1") == untouched)
    }

    @Test func wrappedValueWorksLikeAnArray() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        storage.wrappedValue.append(Todo(id: 1, title: "Read"))
        storage.wrappedValue.append(Todo(id: 2, title: "Write"))
        storage.wrappedValue.removeAll { $0.id == 2 }
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read")])
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security + SwiftUI + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

extension ListStorageTests {

    @Test func projectedValueBindsEachItemByIdentity() {
        let storage: ListStorage<Todo> = ListStorage(UUID().uuidString)
        storage.wrappedValue = [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Write")]
        let elements: ListStorage<Todo>.Elements = storage.projectedValue
        elements[1].wrappedValue.title = "Edit"
        #expect(storage.wrappedValue == [Todo(id: 1, title: "Read"), Todo(id: 2, title: "Edit")])
        #expect(elements.map(\.wrappedValue.id) == [1, 2])
    }

    @Test func projectedValueReportsTheListsSync() {
        let elements: ListStorage<Todo>.Elements = ListStorage<Todo>(UUID().uuidString).projectedValue
        #expect(elements.isEmpty)
        #expect(elements.pending.isEmpty)
        guard case .unknown = elements.status else { Issue.record("Expected unknown"); return }
    }
}
#endif
