// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/VersionedTests.swift
// dependencies: [Protocols/Digestible.swift, Protocols/Versioned.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private final class Note: Versioned {

    var body: String
    var id = UUID()
    var revision = Commit()

    init(body: String) {
        self.body = body
    }

    static func forked(copying parent: Note) -> Note {
        Note(body: parent.body)
    }

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private struct Page: Equatable, Versioned {

    var body: String
    var id = UUID()
    var revision = Commit()

    static func forked(copying parent: Page) -> Page {
        Page(body: parent.body)
    }

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private extension Repository where V == Page {

    @discardableResult
    mutating func committed(_ body: String, onto parent: Page? = nil) throws -> Page {
        guard let parent else { return try commit(Page(body: body)) }
        var child = try fork(parent)
        child.body = body
        return try commit(child)
    }
}

@Suite struct VersionedTests {

    @Test func branchesAreEmptyWithoutCommits() {
        #expect(Repository([Page(body: "A"), Page(body: "B")]).branches.isEmpty)
    }

    @Test func branchesAreIncompleteWhenAncestorIsMissing() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let parent = try repository.committed("Parent", onto: root)
        let child = try repository.committed("Child", onto: parent)
        let branches = Repository([child, parent]).branches
        #expect(branches.count == 1)
        #expect(branches.first?.map(\.body) == ["Parent", "Child"])
        #expect(branches.first?.isComplete == false)
    }

    @Test func branchesBreakTiesByNewestId() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let first = try repository.committed("First", onto: root)
        let second = try repository.committed("Second", onto: root)
        let heads = [first, second].sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(Repository([first, root, second]).branches.map { $0.last?.body } == heads.map(\.body))
        #expect(Repository([second, root, first]).branches.map { $0.last?.body } == heads.map(\.body))
    }

    @Test func branchesFollowParentsFromRootToHead() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let parent = try repository.committed("Parent", onto: root)
        try repository.committed("Child", onto: parent)
        #expect(repository.branches.count == 1)
        #expect(repository.branches.first?.map(\.body) == ["Root", "Parent", "Child"])
        #expect(repository.branches.first?.isComplete == true)
    }

    @Test func branchesKeepIdenticalForksSeparate() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        try repository.committed("Child", onto: root)
        try repository.committed("Child", onto: root)
        #expect(repository.branches.count == 2)
    }

    @Test func branchesLeaveOutUncommittedForks() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        _ = try repository.fork(root)
        #expect(repository.branches.map { $0.map(\.body) } == [["Root"]])
    }

    @Test func branchesSortMostVersionsFirst() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        try repository.committed("Short", onto: root)
        let middle = try repository.committed("Middle", onto: root)
        try repository.committed("Long", onto: middle)
        #expect(repository.branches.map { $0.map(\.body) } == [["Root", "Middle", "Long"], ["Root", "Short"]])
    }

    @Test func commitAddsNewValue() throws {
        var repository = Repository<Page>()
        let page = try repository.commit(Page(body: "Root"))
        #expect(repository.values == [page])
        #expect(page.revision.isCommitted)
        #expect(page.revision.checksum == page.checksum)
        #expect(page.revision.parent == nil)
    }

    @Test func commitEmptyInitializerIsUncommitted() {
        let commit = Commit()
        #expect(commit.checksum == nil)
        #expect(!commit.isCommitted)
        #expect(commit.parent == nil)
    }

    @Test func commitKeepsIdAndParentOfFork() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        var child = try repository.fork(root)
        let id = child.id
        child.body = "Child"
        let committed = try repository.commit(child)
        #expect(committed.id == id)
        #expect(committed.revision.parent == root.id)
        #expect(repository.values.count == 2)
        #expect(repository.uncommitted.isEmpty)
    }

    @Test func commitKeepsUnchangedCommittedValue() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let recommitted = try repository.commit(root)
        #expect(recommitted == root)
        #expect(repository.values == [root])
    }

    @Test func commitRoundTripsThroughCodable() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let revision = try repository.committed("Child", onto: root).revision
        let decoded = try JSONDecoder().decode(Commit.self, from: JSONEncoder().encode(revision))
        #expect(decoded == revision)
    }

    @Test func commitThrowsWhenCommittedClassInstanceChanges() throws {
        var repository = Repository<Note>()
        let note = try repository.commit(Note(body: "Root"))
        note.body = "Edited"
        #expect(throws: VersionedError.committedValueChanged) { try repository.commit(note) }
    }

    @Test func commitThrowsWhenCommittedValueChanges() throws {
        var repository = Repository<Page>()
        var page = try repository.committed("Root")
        page.body = "Edited"
        #expect(throws: VersionedError.committedValueChanged) { try repository.commit(page) }
        #expect(repository.values.map(\.body) == ["Root"])
    }

    @Test func duplicatesListLaterValuesWithRepeatedIds() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        var copy = root
        copy.body = "Copy"
        #expect(Repository([root], [copy]).duplicates.map(\.body) == ["Copy"])
        #expect(repository.duplicates.isEmpty)
    }

    @Test func forkAssignsNewIdAndRecordsParent() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let child = try repository.fork(root)
        #expect(child.id != root.id)
        #expect(child.revision.parent == root.id)
        #expect(child.revision.checksum == child.checksum)
        #expect(!child.revision.isCommitted)
    }

    @Test func forkCommitsUncommittedParentFirst() throws {
        var repository = Repository<Page>()
        let child = try repository.fork(Page(body: "Root"))
        let id = try #require(child.revision.parent)
        let parent = try #require(repository.value(for: id))
        #expect(parent.revision.isCommitted)
        #expect(repository.uncommitted == [child])
    }

    @Test func forkCreatesNewClassInstance() throws {
        var repository = Repository<Note>()
        let note = Note(body: "Root")
        let child = try repository.fork(note)
        child.body = "Child"
        try repository.commit(child)
        #expect(child !== note)
        #expect(note.body == "Root")
        #expect(repository.isAncestor(note, of: child))
    }

    @Test func hasUncommittedChangesIsFalseAfterCommit() throws {
        var repository = Repository<Page>()
        let page = try repository.committed("Root")
        #expect(!page.hasUncommittedChanges)
    }

    @Test func hasUncommittedChangesIsTrueAfterEdit() throws {
        var repository = Repository<Page>()
        var page = try repository.committed("Root")
        page.body = "Edited"
        #expect(page.hasUncommittedChanges)
    }

    @Test func hasUncommittedChangesIsTrueBeforeFirstCommit() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let child = try repository.fork(root)
        #expect(Page(body: "Root").hasUncommittedChanges)
        #expect(child.hasUncommittedChanges)
    }

    @Test func headsListNewestVersionOfEachBranch() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        try repository.committed("Short", onto: root)
        let middle = try repository.committed("Middle", onto: root)
        try repository.committed("Long", onto: middle)
        #expect(repository.heads.map(\.body) == ["Long", "Short"])
    }

    @Test func isAncestorCoversGrandparents() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let parent = try repository.committed("Parent", onto: root)
        let child = try repository.committed("Child", onto: parent)
        #expect(repository.isAncestor(root, of: child))
        #expect(repository.isAncestor(parent, of: child))
    }

    @Test func isAncestorIsFalseForSelfAndDescendants() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let child = try repository.committed("Child", onto: root)
        #expect(!repository.isAncestor(child, of: child))
        #expect(!repository.isAncestor(child, of: root))
    }

    @Test func logListsVersionsNewestFirst() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let parent = try repository.committed("Parent", onto: root)
        let child = try repository.committed("Child", onto: parent)
        #expect(repository.log(from: child).map(\.body) == ["Child", "Parent", "Root"])
    }

    @Test func mergeBaseFindsNearestSharedAncestor() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        let shared = try repository.committed("Shared", onto: root)
        let ours = try repository.committed("Ours", onto: shared)
        let theirs = try repository.committed("Theirs", onto: shared)
        #expect(repository.mergeBase(of: ours, and: theirs) == shared)
        #expect(repository.mergeBase(of: shared, and: theirs) == shared)
    }

    @Test func mergeBaseIsNilForUnrelatedHistories() throws {
        var repository = Repository<Page>()
        let first = try repository.committed("First")
        let second = try repository.committed("Second")
        #expect(repository.mergeBase(of: first, and: second) == nil)
    }

    @Test func uncommittedListsNewAndForkedValues() throws {
        var repository = Repository([Page(body: "Draft")])
        let root = try repository.committed("Root")
        _ = try repository.fork(root)
        #expect(repository.uncommitted.map(\.body) == ["Draft", "Root"])
    }

    @Test func valueForIdFindsVersionOrReturnsNil() throws {
        var repository = Repository<Page>()
        let root = try repository.committed("Root")
        #expect(repository.value(for: root.id) == root)
        #expect(repository.value(for: UUID()) == nil)
    }
}
#endif
