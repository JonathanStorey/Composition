// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/VersionedTests.swift
// dependencies: [Protocols/Digestible.swift, Protocols/Versioned.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Page: Versioned {

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

@Suite struct VersionedTests {

    @Test func commitDecodesWhatItEncodes() throws {
        let commit: Commit = Commit(checksum: Page(body: "A").checksum, isCommitted: true, parent: UUID())
        let data: Data = try JSONEncoder().encode(commit)
        #expect(try JSONDecoder().decode(Commit.self, from: data) == commit)
    }

    @Test func commitIsEmptyOnlyWhenNew() {
        #expect(Commit().isEmpty)
        #expect(!Commit(checksum: nil, isCommitted: false, parent: UUID()).isEmpty)
        #expect(!Commit(checksum: Page(body: "A").checksum, isCommitted: false, parent: nil).isEmpty)
    }

    @Test func commitIsRootWithoutParent() {
        #expect(Commit().isRoot)
        #expect(!Commit(checksum: nil, isCommitted: false, parent: UUID()).isRoot)
    }

    @Test func commitMatchesOnlyItsChecksum() {
        let page: Page = Page(body: "A")
        let commit: Commit = Commit(checksum: page.checksum, isCommitted: true, parent: nil)
        #expect(commit.matches(page.checksum))
        #expect(!commit.matches(Page(body: "B").checksum))
        #expect(!Commit().matches(page.checksum))
    }

    @Test func forkedCopiesOnlyContent() {
        var parent: Page = Page(body: "A")
        parent.revision = Commit(checksum: parent.checksum, isCommitted: true, parent: nil)
        let child: Page = Page.forked(copying: parent)
        #expect(child.body == parent.body)
        #expect(child.id != parent.id)
        #expect(child.revision.isEmpty)
    }

    @Test func hasUncommittedChangesAfterEdit() {
        var page: Page = Page(body: "A")
        page.revision = Commit(checksum: page.checksum, isCommitted: true, parent: nil)
        page.body = "B"
        #expect(page.hasUncommittedChanges)
    }

    @Test func hasUncommittedChangesUntilCommitted() {
        var page: Page = Page(body: "A")
        #expect(page.hasUncommittedChanges)
        page.revision = Commit(checksum: page.checksum, isCommitted: false, parent: UUID())
        #expect(page.hasUncommittedChanges)
        page.revision = Commit(checksum: page.checksum, isCommitted: true, parent: page.revision.parent)
        #expect(!page.hasUncommittedChanges)
    }

    @Test func revisionIsLeftOutOfChecksum() {
        var page: Page = Page(body: "A")
        let checksum: Checksum = page.checksum
        page.revision = Commit(checksum: checksum, isCommitted: true, parent: UUID())
        #expect(page.checksum == checksum)
    }
}
#endif
