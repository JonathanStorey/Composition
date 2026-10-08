#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Page: Equatable, Versioned {

    var body: String
    var revision: Commit?

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private func committed(_ body: String, onto parent: Page? = nil) throws -> Page {
    var page = Page(body: body)
    try page.commit(onto: parent)
    return page
}

@Suite struct VersionedTests {

    @Test func branchesAreEmptyWithoutCommits() {
        #expect([Page(body: "A"), Page(body: "B")].branches.isEmpty)
    }

    @Test func branchesAreIncompleteWhenAncestorIsMissing() throws {
        let parent = try committed("Parent", onto: committed("Root"))
        let child = try committed("Child", onto: parent)
        let branches = [child, parent].branches
        #expect(branches.count == 1)
        #expect(branches.first?.map(\.body) == ["Parent", "Child"])
        #expect(branches.first?.isComplete == false)
    }

    @Test func branchesBreakTiesByLastHash() throws {
        let root = try committed("Root")
        let first = try committed("First", onto: root)
        let second = try committed("Second", onto: root)
        let heads = [first, second].sorted { ($0.revision?.hash.bytes ?? Data()).lexicographicallyPrecedes($1.revision?.hash.bytes ?? Data()) }
        #expect([first, root, second].branches.map { $0.last?.body } == heads.map(\.body))
        #expect([second, root, first].branches.map { $0.last?.body } == heads.map(\.body))
    }

    @Test func branchesCollapseIdenticalCommits() throws {
        let root = try committed("Root")
        let first = try committed("Child", onto: root)
        let second = try committed("Child", onto: root)
        #expect([root, first, second].branches.count == 1)
    }

    @Test func branchesEqualWhenBuiltFromSameValues() throws {
        let root = try committed("Root")
        let child = try committed("Child", onto: root)
        #expect([root, child].branches == [child, root].branches)
        #expect([root, child].branches != [root].branches)
    }

    @Test func branchesFollowParentsFromRootToHead() throws {
        let root = try committed("Root")
        let parent = try committed("Parent", onto: root)
        let child = try committed("Child", onto: parent)
        let branches = [child, root, parent].branches
        #expect(branches.count == 1)
        #expect(branches.first?.map(\.body) == ["Root", "Parent", "Child"])
        #expect(branches.first?.last?.body == "Child")
        #expect(branches.first?.isComplete == true)
    }

    @Test func branchesSortMostCommitsFirst() throws {
        let root = try committed("Root")
        let short = try committed("Short", onto: root)
        let middle = try committed("Middle", onto: root)
        let long = try committed("Long", onto: middle)
        let branches = [short, root, long, middle].branches
        #expect(branches.map { $0.map(\.body) } == [["Root", "Middle", "Long"], ["Root", "Short"]])
    }

    @Test func childHashDependsOnParent() throws {
        let first = try committed("Child", onto: committed("A"))
        let second = try committed("Child", onto: committed("B"))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func commitAgainThrows() throws {
        var page = try committed("Root")
        #expect(throws: Commit.Error.alreadyCommitted) { try page.commit() }
        page.body = "Edited"
        #expect(throws: Commit.Error.alreadyCommitted) { try page.commit() }
    }

    @Test func commitIsStableForEqualContent() throws {
        let parent = try committed("Root")
        #expect(try committed("Draft", onto: parent).revision == committed("Draft", onto: parent).revision)
    }

    @Test func commitOntoModifiedParentThrows() throws {
        var parent = try committed("Root")
        parent.body = "Edited"
        #expect(throws: Commit.Error.modifiedParent) { try committed("Child", onto: parent) }
    }

    @Test func commitOntoUncommittedParentThrows() {
        #expect(throws: Commit.Error.uncommittedParent) { try committed("Child", onto: Page(body: "Root")) }
    }

    @Test func commitRecordsParentHash() throws {
        let parent = try committed("Root")
        let child = try committed("Child", onto: parent)
        #expect(child.revision?.parent == parent.revision?.hash)
        #expect(parent.revision?.parent == nil)
    }

    @Test func commitRoundTripsThroughCodable() throws {
        let revision = try #require(try committed("Root").revision)
        let decoded = try JSONDecoder().decode(Commit.self, from: JSONEncoder().encode(revision))
        #expect(decoded == revision)
    }

    @Test func commitStatusIsCommittedAfterCommit() throws {
        #expect(try committed("Root").commitStatus == .committed)
    }

    @Test func commitStatusIsModifiedAfterEdit() throws {
        var page = try committed("Root")
        page.body = "Edited"
        #expect(page.commitStatus == .modified)
    }

    @Test func commitStatusIsUncommittedBeforeFirstCommit() {
        #expect(Page(body: "Root").commitStatus == .uncommitted)
    }

    @Test func duplicatesIsEmptyWithoutRepeatedCommits() throws {
        let root = try committed("Root")
        let child = try committed("Child", onto: root)
        #expect([root, child, Page(body: "Draft")].duplicates.isEmpty)
    }

    @Test func duplicatesListLaterIdenticalCommits() throws {
        let root = try committed("Root")
        let first = try committed("Child", onto: root)
        var second = try committed("Child", onto: root)
        second.body = "Edited"
        #expect([root, first, second].duplicates.map(\.body) == ["Edited"])
    }

    @Test func grandchildHashDependsOnGrandparent() throws {
        let first = try committed("Child", onto: committed("Parent", onto: committed("A")))
        let second = try committed("Child", onto: committed("Parent", onto: committed("B")))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func hashChangesWhenContentChanges() throws {
        #expect(try committed("A").revision?.hash != committed("B").revision?.hash)
    }

    @Test func isChildIsFalseForGrandparent() throws {
        let grandparent = try committed("Root")
        let child = try committed("Child", onto: committed("Parent", onto: grandparent))
        #expect(!child.isChild(of: grandparent))
    }

    @Test func isChildIsFalseWhenChildChanges() throws {
        let parent = try committed("Root")
        var child = try committed("Child", onto: parent)
        child.body = "Edited"
        #expect(!child.isChild(of: parent))
    }

    @Test func isChildIsFalseWhenParentChanges() throws {
        var parent = try committed("Root")
        let child = try committed("Child", onto: parent)
        parent.body = "Edited"
        #expect(!child.isChild(of: parent))
    }

    @Test func isChildIsTrueForDirectChild() throws {
        let parent = try committed("Root")
        #expect(try committed("Child", onto: parent).isChild(of: parent))
    }

    @Test func revisedCommitsChangesOntoOriginal() throws {
        let root = try committed("Root")
        let child = try #require(try root.revised { $0.body = "Edited" })
        #expect(child.body == "Edited")
        #expect(child.isChild(of: root))
        #expect(root.body == "Root")
    }

    @Test func revisedIsNilWhenContentIsUnchanged() throws {
        let root = try committed("Root")
        #expect(try root.revised { $0.body = "Root" } == nil)
    }

    @Test func revisedThrowsWhenOriginalIsModified() throws {
        var root = try committed("Root")
        root.body = "Edited"
        #expect(throws: Commit.Error.modifiedParent) { try root.revised { $0.body = "Child" } }
    }

    @Test func uncommittedIsEmptyWhenAllCommitted() throws {
        let root = try committed("Root")
        #expect([root].uncommitted.isEmpty)
    }

    @Test func uncommittedListsValuesWithoutRevision() throws {
        let root = try committed("Root")
        var edited = try committed("Edited")
        edited.body = "Changed"
        #expect([root, Page(body: "Draft"), edited].uncommitted.map(\.body) == ["Draft"])
    }
}
#endif
