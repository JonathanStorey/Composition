// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/RecordCodableTests.swift
// dependencies: [Protocols/RecordCodable.swift]

// MARK: - CloudKit + Foundation

#if canImport(CloudKit) && canImport(Foundation)
import CloudKit
import Foundation
import Testing
@testable import Composition

@Suite struct RecordCodableTests {

    @Test func codableValueRoundTripsThroughTheValueField() throws {
        let record: CKRecord = CKRecord(recordType: "Book")
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record["value"] is Data)
        #expect(try Book(from: record) == Book(pages: 412, title: "Dune"))
    }

    @Test func codableValueThrowsWithoutAValueField() {
        #expect(throws: DecodingError.self) { try Book(from: CKRecord(recordType: "Book")) }
    }

    @Test func encodeLeavesTheRecordsIdentityAsItIs() throws {
        let record: CKRecord = CKRecord(recordType: "Book", recordID: CKRecord.ID(recordName: "dune", zoneID: CKRecordZone.ID(zoneName: "Library")))
        try Book(pages: 412, title: "Dune").encode(to: record)
        #expect(record.recordType == "Book")
        #expect(record.recordID.recordName == "dune")
        #expect(record.recordID.zoneID.zoneName == "Library")
    }
}

extension RecordCodableTests {

    struct Book: Codable, Equatable, RecordCodable {

        let pages: Int
        let title: String
    }
}
#endif

// MARK: - CloudKit + Foundation + Observation + os + Security

#if canImport(CloudKit) && canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
@Suite struct RecordContextTests {

    let folder: URL = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)

    @Test func changesListInsertedChangedAndDeletedRecords() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "One"))
        context.save()
        try context.insert(Note(id: 1, rank: 2, title: "One"))
        try context.insert(Note(id: 2, rank: 1, title: "Two"))
        context.delete(Note(id: 3, rank: 1, title: "Three"))
        #expect(context.changedRecords.map(\.recordName) == ["Note.1"])
        #expect(context.insertedRecords.map(\.recordName) == ["Note.2"])
        #expect(context.deletedRecords.map(\.recordName) == ["Note.3"])
    }

    @Test func contextKeepsSavedValuesForTheNextContext() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "One"))
        context.save()
        context.flush()
        #expect(try makeContext().fetch(RecordDescriptor<Note>()) == [Note(id: 1, rank: 1, title: "One")])
    }

    @Test func deleteRemovesTheValue() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "One"))
        context.save()
        context.delete(Note(id: 1, rank: 1, title: "One"))
        #expect(try context.fetch(RecordDescriptor<Note>()).isEmpty)
        #expect(context.record(for: CKRecord.ID(recordName: "Note.1", zoneID: CKRecordZone.ID(zoneName: "Composition"))) == nil)
    }

    @Test func deleteWhereRemovesOnlyTheMatchingValues() throws {
        let context: RecordContext = makeContext()
        try insertNotes(into: context)
        try context.delete(Note.self, where: #Predicate<Note> { $0.rank > 1 })
        #expect(try context.fetch(RecordDescriptor<Note>()).map(\.id) == [1])
    }

    @Test func fetchAppliesThePredicateSortAndLimit() throws {
        let context: RecordContext = makeContext()
        try insertNotes(into: context)
        var descriptor: RecordDescriptor<Note> = RecordDescriptor(predicate: #Predicate<Note> { $0.rank > 1 }, sortBy: [SortDescriptor(\Note.rank, order: .reverse)])
        #expect(try context.fetch(descriptor).map(\.id) == [3, 2])
        descriptor.fetchLimit = 1
        #expect(try context.fetch(descriptor).map(\.id) == [3])
    }

    @Test func fetchCountAndIdentifiersFollowTheDescriptor() throws {
        let context: RecordContext = makeContext()
        try insertNotes(into: context)
        let descriptor: RecordDescriptor<Note> = RecordDescriptor(predicate: #Predicate<Note> { $0.rank > 1 })
        #expect(try context.fetchCount(descriptor) == 2)
        #expect(try context.fetchIdentifiers(descriptor).map(\.recordName) == ["Note.2", "Note.3"])
        #expect(try context.fetchIdentifiers(descriptor).allSatisfy { $0.zoneID.zoneName == "Composition" })
    }

    @Test func fetchFollowsRecordNamesWithoutSortDescriptors() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 2, rank: 1, title: "Two"))
        try context.insert(Note(id: 1, rank: 2, title: "One"))
        #expect(try context.fetch(RecordDescriptor<Note>()).map(\.id) == [1, 2])
    }

    @Test func fetchKeepsZonesApart() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "Home"))
        try context.insert(Note(id: 1, rank: 1, title: "Work"), zone: "Work")
        #expect(try context.fetch(RecordDescriptor<Note>()).map(\.title) == ["Home"])
        #expect(try context.fetch(RecordDescriptor<Note>(zone: "Work")).map(\.title) == ["Work"])
    }

    @Test func insertReplacesTheValueWithTheSameIdentifier() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "Draft"))
        context.save()
        try context.insert(Note(id: 1, rank: 1, title: "Final"))
        context.save()
        #expect(try context.fetch(RecordDescriptor<Note>()) == [Note(id: 1, rank: 1, title: "Final")])
    }

    @Test func recordNameJoinsTheTypeAndIdentifier() {
        #expect(RecordContext.recordName(of: Note(id: 42, rank: 1, title: "Answer")) == "Note.42")
    }

    @Test func recordTypeDropsTheModuleParentsAndGenericArguments() {
        #expect(RecordContext.recordType(of: Note.self) == "Note")
        #expect(RecordContext.recordType(of: [Note].self) == "Array")
    }

    #if os(macOS)
    @Test func refreshThrowsWhenTheAppCantUseCloudKit() async {
        await #expect(throws: CKError.self) { try await makeContext().refresh() }
    }
    #endif

    @Test func rollbackDiscardsUnsavedChanges() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "One"))
        context.save()
        try context.insert(Note(id: 2, rank: 1, title: "Two"))
        #expect(context.hasChanges)
        context.rollback()
        #expect(!context.hasChanges)
        #expect(try context.fetch(RecordDescriptor<Note>()).map(\.id) == [1])
    }

    @Test func saveKeepsTheChangesAndClearsThem() throws {
        let context: RecordContext = makeContext()
        try context.insert(Note(id: 1, rank: 1, title: "One"))
        context.save()
        #expect(!context.hasChanges)
        #expect(context.record(for: CKRecord.ID(recordName: "Note.1", zoneID: CKRecordZone.ID(zoneName: "Composition")))?.recordType == "Note")
    }

    /// Inserts three notes ranked by their identifiers.
    private func insertNotes(into context: RecordContext) throws {
        for id: Int in 1...3 {
            try context.insert(Note(id: id, rank: id, title: "Note \(id)"))
        }
    }

    /// A context in the test's own folder that saves only when told to.
    private func makeContext() -> RecordContext {
        let context: RecordContext = RecordContext(nil, folder: folder)
        context.autosaveEnabled = false
        return context
    }
}

extension RecordContextTests {

    struct Note: Codable, Equatable, Identifiable, RecordCodable {

        let id: Int
        let rank: Int
        let title: String
    }
}
#endif
