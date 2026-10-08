#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private final class Note: Versioned {

    var body: String
    var revision: Commit?

    init(body: String) {
        self.body = body
    }

    static func forked(from parent: Note) -> Note {
        Note(body: parent.body)
    }

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private struct Page: Equatable, Versioned {

    var body: String
    var revision: Commit?

    static func forked(from parent: Page) -> Page {
        Page(body: parent.body)
    }

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private func committed(_ body: String, onto parent: Page? = nil) -> Page {
    var page = parent ?? Page(body: body)
    page.body = body
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

    @Test func branchesBreakTiesByLastHash() {
        let root = committed("Root")
        let first = committed("First", onto: root)
        let second = committed("Second", onto: root)
        let heads = [first, second].sorted { ($0.revision?.hash.bytes ?? Data()).lexicographicallyPrecedes($1.revision?.hash.bytes ?? Data()) }
        #expect([first, root, second].branches.map { $0.last?.body } == heads.map(\.body))
        #expect([second, root, first].branches.map { $0.last?.body } == heads.map(\.body))
    }

    @Test func branchesCollapseIdenticalCommits() {
        let root = committed("Root")
        let first = committed("Child", onto: root)
        let second = committed("Child", onto: root)
        #expect([root, first, second].branches.count == 1)
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
        #expect(branches.first?.last?.body == "Child")
        #expect(branches.first?.isComplete == true)
    }

    @Test func branchesSortMostCommitsFirst() {
        let root = committed("Root")
        let short = committed("Short", onto: root)
        let middle = committed("Middle", onto: root)
        let long = committed("Long", onto: middle)
        let branches = [short, root, long, middle].branches
        #expect(branches.map { $0.map(\.body) } == [["Root", "Middle", "Long"], ["Root", "Short"]])
    }

    @Test func childHashDependsOnParent() {
        let first = committed("Child", onto: committed("A"))
        let second = committed("Child", onto: committed("B"))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func commitIsStableForEqualContent() {
        let parent = committed("Root")
        #expect(committed("Draft", onto: parent).revision == committed("Draft", onto: parent).revision)
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

    @Test func commitOfModifiedValueChainsOntoItsRevision() {
        var page = committed("Root")
        let previous = page.revision
        page.body = "Edited"
        page.commit()
        #expect(page.revision?.matches(page) == true)
        #expect(page.revision?.parent == previous?.hash)
    }

    @Test func commitRecordsParentHash() {
        let parent = committed("Root")
        let child = committed("Child", onto: parent)
        #expect(child.revision?.parent == parent.revision?.hash)
        #expect(parent.revision?.parent == nil)
    }

    @Test func commitRoundTripsThroughCodable() throws {
        let revision = try #require(committed("Root").revision)
        let decoded = try JSONDecoder().decode(Commit.self, from: JSONEncoder().encode(revision))
        #expect(decoded == revision)
    }

    @Test func commitUpdatesValueInPlace() {
        var page = committed("Root")
        let root = page
        page.body = "Child"
        let result = page.commit()
        #expect(page.body == "Child")
        #expect(result == page)
        #expect(page.isChild(of: root))
    }

    @Test func duplicatesIsEmptyWithoutRepeatedCommits() {
        let root = committed("Root")
        let child = committed("Child", onto: root)
        #expect([root, child, Page(body: "Draft")].duplicates.isEmpty)
    }

    @Test func duplicatesListLaterIdenticalCommits() {
        let root = committed("Root")
        let first = committed("Child", onto: root)
        var second = committed("Child", onto: root)
        second.body = "Edited"
        #expect([root, first, second].duplicates.map(\.body) == ["Edited"])
    }

    @Test func forkCommitsModifiedParentFirst() {
        var parent = committed("Root")
        parent.body = "Edited"
        var child = parent.fork()
        child.body = "Child"
        child.commit()
        #expect(parent.revision?.matches(parent) == true)
        #expect(child.isChild(of: parent))
    }

    @Test func forkCommitsUncommittedParentFirst() {
        var parent = Page(body: "Root")
        var child = parent.fork()
        child.body = "Child"
        child.commit()
        #expect(parent.revision?.matches(parent) == true)
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

    @Test func forkKeepsRevisionWhenContentMatches() {
        var root = committed("Root")
        let child = root.fork()
        #expect(child == root)
    }

    @Test func forkLeavesParentContentUnchanged() {
        var root = committed("Root")
        var child = root.fork()
        child.body = "Child"
        child.commit()
        #expect(root.body == "Root")
        #expect(root.revision?.matches(root) == true)
        #expect(child.isChild(of: root))
    }

    @Test func grandchildHashDependsOnGrandparent() {
        let first = committed("Child", onto: committed("Parent", onto: committed("A")))
        let second = committed("Child", onto: committed("Parent", onto: committed("B")))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func hashChangesWhenContentChanges() {
        #expect(committed("A").revision?.hash != committed("B").revision?.hash)
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

    @Test func matchesIsFalseAfterEdit() {
        var page = committed("Root")
        page.body = "Edited"
        #expect(page.revision?.matches(page) == false)
    }

    @Test func matchesIsNilBeforeFirstCommit() {
        let page = Page(body: "Root")
        #expect(page.revision?.matches(page) == nil)
    }

    @Test func matchesIsTrueAfterCommit() {
        let page = committed("Root")
        #expect(page.revision?.matches(page) == true)
    }

    @Test func uncommittedIsEmptyWhenAllCommitted() {
        let root = committed("Root")
        #expect([root].uncommitted.isEmpty)
    }

    @Test func uncommittedListsValuesWithoutRevision() {
        let root = committed("Root")
        var edited = committed("Edited")
        edited.body = "Changed"
        #expect([root, Page(body: "Draft"), edited].uncommitted.map(\.body) == ["Draft"])
    }
}
#endif
