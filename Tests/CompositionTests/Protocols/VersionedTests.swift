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
