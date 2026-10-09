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
    var revision: Commit?

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
    var revision: Commit?

    static func forked(copying parent: Page) -> Page {
        Page(body: parent.body)
    }

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private func committed(_ body: String, onto parent: Page? = nil) -> Page {
    var page = Page(body: body)
    if var parent {
        page = parent.fork()
        page.body = body
    }
    return page.commit()
}

@Suite struct VersionedTests {

    @Test func branchesAreEmptyWithoutCommits() {
        #expect([Page(body: "A"), Page(body: "B")].branches.isEmpty)
    }

    @Test func branchesAreIncompleteWhenAncestorIsMissing() {
        let parent = committed("Parent", onto: committed("Root"))
        let child = committed("Child", onto: parent)
        let branches = [child, parent].branches
        #expect(branches.count == 1)
        #expect(branches.first?.map(\.body) == ["Parent", "Child"])
        #expect(branches.first?.isComplete == false)
    }

    @Test func branchesBreakTiesByNewestId() {
        let root = committed("Root")
        let first = committed("First", onto: root)
        let second = committed("Second", onto: root)
        let heads = [first, second].sorted { $0.id.uuidString < $1.id.uuidString }
        #expect([first, root, second].branches.map { $0.last?.body } == heads.map(\.body))
        #expect([second, root, first].branches.map { $0.last?.body } == heads.map(\.body))
    }

    @Test func branchesEqualWhenBuiltFromSameValues() {
        let root = committed("Root")
        let child = committed("Child", onto: root)
        #expect([root, child].branches == [child, root].branches)
        #expect([root, child].branches != [root].branches)
    }

    @Test func branchesFollowParentsFromRootToHead() {
        let root = committed("Root")
        let parent = committed("Parent", onto: root)
        let child = committed("Child", onto: parent)
        let branches = [child, root, parent].branches
        #expect(branches.count == 1)
        #expect(branches.first?.map(\.body) == ["Root", "Parent", "Child"])
        #expect(branches.first?.isComplete == true)
    }

    @Test func branchesKeepIdenticalForksSeparate() {
        let root = committed("Root")
        let first = committed("Child", onto: root)
        let second = committed("Child", onto: root)
        #expect([root, first, second].branches.count == 2)
    }

    @Test func branchesSortMostCommitsFirst() {
        let root = committed("Root")
        let short = committed("Short", onto: root)
        let middle = committed("Middle", onto: root)
        let long = committed("Long", onto: middle)
        let branches = [short, root, long, middle].branches
        #expect(branches.map { $0.map(\.body) } == [["Root", "Middle", "Long"], ["Root", "Short"]])
    }

    @Test func commitIsStableForEqualContent() {
        let parent = committed("Root")
        #expect(committed("Draft", onto: parent).revision == committed("Draft", onto: parent).revision)
    }

    @Test func commitKeepsIdAndParentWhenContentChanges() {
        let root = committed("Root")
        var page = committed("Child", onto: root)
        let id = page.id
        page.body = "Edited"
        page.commit()
        #expect(page.id == id)
        #expect(page.revision?.parent == root.id)
        #expect(page.revision?.checksum == page.checksum)
    }

    @Test func commitKeepsRevisionWhenContentMatches() {
        var page = committed("Root")
        let revision = page.revision
        page.commit()
        #expect(page.revision == revision)
        page.body = "Root"
        page.commit()
        #expect(page.revision == revision)
    }

    @Test func commitRecordsChecksumOfContent() {
        let page = committed("Root")
        #expect(page.revision?.checksum == page.checksum)
        #expect(page.revision?.parent == nil)
    }

    @Test func commitReturnsUpdatedValue() {
        var page = Page(body: "Root")
        let result = page.commit()
        #expect(result == page)
        #expect(page.revision != nil)
    }

    @Test func commitRoundTripsThroughCodable() throws {
        let revision = try #require(committed("Child", onto: committed("Root")).revision)
        let decoded = try JSONDecoder().decode(Commit.self, from: JSONEncoder().encode(revision))
        #expect(decoded == revision)
    }

    @Test func duplicatesIsEmptyWithoutRepeatedIds() {
        let root = committed("Root")
        let child = committed("Child", onto: root)
        #expect([root, child, Page(body: "Draft")].duplicates.isEmpty)
    }

    @Test func duplicatesListLaterValuesWithRepeatedIds() {
        let root = committed("Root")
        let child = committed("Child", onto: root)
        var copy = child
        copy.body = "Edited"
        #expect([root, child, copy].duplicates.map(\.body) == ["Edited"])
    }

    @Test func forkAssignsNewIdAndRecordsParent() {
        var root = committed("Root")
        let child = root.fork()
        #expect(child.id != root.id)
        #expect(child.revision?.parent == root.id)
    }

    @Test func forkCommitsModifiedParentFirst() {
        var parent = committed("Root")
        parent.body = "Edited"
        var child = parent.fork()
        child.body = "Child"
        child.commit()
        #expect(!parent.hasUncommittedChanges)
        #expect(child.isChild(of: parent))
    }

    @Test func forkCommitsUncommittedParentFirst() {
        var parent = Page(body: "Root")
        var child = parent.fork()
        child.body = "Child"
        child.commit()
        #expect(!parent.hasUncommittedChanges)
        #expect(child.isChild(of: parent))
    }

    @Test func forkCreatesNewClassInstance() {
        var note = Note(body: "Root")
        var child = note.fork()
        child.body = "Child"
        child.commit()
        #expect(child !== note)
        #expect(note.body == "Root")
        #expect(child.isChild(of: note))
    }

    @Test func forkLeavesParentContentUnchanged() {
        var root = committed("Root")
        var child = root.fork()
        child.body = "Child"
        child.commit()
        #expect(root.body == "Root")
        #expect(!root.hasUncommittedChanges)
        #expect(child.isChild(of: root))
    }

    @Test func forkStartsWithoutUncommittedChanges() {
        var root = committed("Root")
        let child = root.fork()
        #expect(!child.hasUncommittedChanges)
        #expect(child.isChild(of: root))
    }

    @Test func hasUncommittedChangesIsFalseAfterCommit() {
        #expect(!committed("Root").hasUncommittedChanges)
    }

    @Test func hasUncommittedChangesIsTrueAfterEdit() {
        var page = committed("Root")
        page.body = "Edited"
        #expect(page.hasUncommittedChanges)
    }

    @Test func hasUncommittedChangesIsTrueBeforeFirstCommit() {
        #expect(Page(body: "Root").hasUncommittedChanges)
    }

    @Test func isChildIsFalseForGrandparent() {
        let grandparent = committed("Root")
        let child = committed("Child", onto: committed("Parent", onto: grandparent))
        #expect(!child.isChild(of: grandparent))
    }

    @Test func isChildIsFalseWhenChildChanges() {
        let parent = committed("Root")
        var child = committed("Child", onto: parent)
        child.body = "Edited"
        #expect(!child.isChild(of: parent))
    }

    @Test func isChildIsFalseWhenParentChanges() {
        var parent = committed("Root")
        let child = committed("Child", onto: parent)
        parent.body = "Edited"
        #expect(!child.isChild(of: parent))
    }

    @Test func isChildIsTrueForDirectChild() {
        let parent = committed("Root")
        #expect(committed("Child", onto: parent).isChild(of: parent))
    }

    @Test func uncommittedIsEmptyWhenAllCommitted() {
        #expect([committed("Root")].uncommitted.isEmpty)
    }

    @Test func uncommittedListsValuesWithoutRevision() {
        let root = committed("Root")
        var edited = committed("Edited")
        edited.body = "Changed"
        #expect([root, Page(body: "Draft"), edited].uncommitted.map(\.body) == ["Draft"])
    }
}
#endif
