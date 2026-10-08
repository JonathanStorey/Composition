#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Page: Versioned {

    let timestamp = UUID.timestamp
    var body: String
    var repository = "Notes"
    var revision: Commit?

    func digest(into digester: inout Digester) {
        digester.combine(body)
    }
}

private func committed(_ body: String, onto parent: Page? = nil, repository: String = "Notes") throws -> Page {
    var page = Page(body: body, repository: repository)
    page.revision = try page.commit(onto: parent)
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

    @Test func branchesCollapseIdenticalCommits() throws {
        let root = try committed("Root")
        let first = try committed("Child", onto: root)
        let second = try committed("Child", onto: root)
        #expect([root, first, second].branches.count == 1)
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

    @Test func branchesKeepTheirRepository() throws {
        let notes = try committed("Child", onto: committed("Root", repository: "Notes"), repository: "Notes")
        let drafts = try committed("Draft", repository: "Drafts")
        #expect(Set([notes, drafts].branches.map(\.repository)) == ["Notes", "Drafts"])
    }

    @Test func branchesSplitAtForkNewestHeadFirst() throws {
        let root = try committed("Root")
        let older = try committed("Older", onto: root)
        let newer = try committed("Newer", onto: root)
        let branches = [root, older, newer].branches
        #expect(branches.map { $0.map(\.body) } == [["Root", "Newer"], ["Root", "Older"]])
    }

    @Test func childHashDependsOnParent() throws {
        let first = try committed("Child", onto: committed("A"))
        let second = try committed("Child", onto: committed("B"))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func commitIsStableForEqualContent() throws {
        let parent = try committed("Root")
        #expect(try committed("Draft", onto: parent).revision == committed("Draft", onto: parent).revision)
    }

    @Test func commitOntoChangedParentThrows() throws {
        var parent = try committed("Root")
        parent.body = "Edited"
        #expect(throws: CommitError.expiredParent) { try committed("Child", onto: parent) }
    }

    @Test func commitOntoParentFromAnotherRepositoryThrows() throws {
        let parent = try committed("Root", repository: "Other")
        #expect(throws: CommitError.differentRepository) { try committed("Child", onto: parent) }
    }

    @Test func commitOntoRenamedParentThrows() throws {
        var parent = try committed("Root")
        parent.repository = "Renamed"
        #expect(throws: CommitError.expiredParent) { try committed("Child", onto: parent, repository: "Renamed") }
    }

    @Test func commitOntoUncommittedParentThrows() {
        #expect(throws: CommitError.uncommittedParent) { try committed("Child", onto: Page(body: "Root")) }
    }

    @Test func commitRoundTripsThroughCodable() throws {
        let revision = try #require(try committed("Root").revision)
        let decoded = try JSONDecoder().decode(Commit.self, from: JSONEncoder().encode(revision))
        #expect(decoded == revision)
    }

    @Test func grandchildHashDependsOnGrandparent() throws {
        let first = try committed("Child", onto: committed("Parent", onto: committed("A")))
        let second = try committed("Child", onto: committed("Parent", onto: committed("B")))
        #expect(first.revision?.hash != second.revision?.hash)
    }

    @Test func hashChangesWhenContentChanges() throws {
        #expect(try committed("A").revision?.hash != committed("B").revision?.hash)
    }

    @Test func hashChangesWhenRepositoryChanges() throws {
        #expect(try committed("Root", repository: "A").revision?.hash != committed("Root", repository: "B").revision?.hash)
    }

    @Test func hashIgnoresTimestamp() throws {
        let first = try committed("Root")
        let second = try committed("Root")
        #expect(first.timestamp != second.timestamp)
        #expect(first.revision?.hash == second.revision?.hash)
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

    @Test func isCommittedIsFalseAfterEdit() throws {
        var page = try committed("Root")
        page.body = "Edited"
        #expect(!page.isCommitted)
    }

    @Test func isCommittedIsFalseAfterRepositoryRename() throws {
        var page = try committed("Root")
        page.repository = "Renamed"
        #expect(!page.isCommitted)
    }

    @Test func isCommittedIsFalseBeforeFirstCommit() {
        #expect(!Page(body: "Root").isCommitted)
    }

    @Test func isCommittedIsTrueAfterCommit() throws {
        #expect(try committed("Root").isCommitted)
    }

    @Test func repositoriesGroupsValuesByName() {
        let pages = [Page(body: "A", repository: "One"), Page(body: "B", repository: "Two"), Page(body: "C", repository: "One")]
        let repositories = pages.repositories
        #expect(repositories.keys.sorted() == ["One", "Two"])
        #expect(repositories["One"]?.map(\.body) == ["A", "C"])
        #expect(repositories["Two"]?.map(\.body) == ["B"])
    }

    @Test func repositoriesIsEmptyForEmptyCollection() {
        #expect([Page]().repositories.isEmpty)
    }

    @Test func subscriptIsEmptyForUnknownRepository() {
        #expect([Page(body: "A")][repository: "Missing"].isEmpty)
    }

    @Test func subscriptReturnsValuesInRepository() {
        let pages = [Page(body: "A", repository: "One"), Page(body: "B", repository: "Two"), Page(body: "C", repository: "One")]
        #expect(pages[repository: "One"].map(\.body) == ["A", "C"])
    }
}
#endif
