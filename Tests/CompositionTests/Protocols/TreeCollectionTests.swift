// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/TreeCollectionTests.swift
// dependencies: [Protocols/TreeCollection.swift, Protocols/TreeNode.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

private struct Version: TreeNode {

    let parent: UUID?
    var id: UUID = UUID()
}

@Suite struct TreeCollectionTests {

    let first: Version
    let grandchild: Version
    let root: Version = Version(parent: nil)
    let second: Version
    let versions: [Version]

    init() {
        first = Version(parent: root.id)
        second = Version(parent: root.id)
        grandchild = Version(parent: first.id)
        versions = [root, first, second, grandchild]
    }

    @Test func ancestorsRunFromParentToRoot() {
        #expect(versions.ancestors(of: grandchild).map(\.id) == [first.id, root.id])
    }

    @Test func ancestorsStopAtCycle() {
        let a: UUID = UUID()
        let b: UUID = UUID()
        let loop: [Version] = [Version(parent: b, id: a), Version(parent: a, id: b)]
        #expect(loop.ancestors(of: loop[0]).map(\.id) == [b, a])
    }

    @Test func ancestorsStopAtMissingParent() {
        #expect([grandchild].ancestors(of: grandchild).isEmpty)
    }

    @Test func childrenAreNodesNamingTheParent() {
        #expect(versions.children(of: root).map(\.id) == [first.id, second.id])
    }

    @Test func childrenOfLeafAreEmpty() {
        #expect(versions.children(of: grandchild).isEmpty)
    }

    @Test func leavesAreNodesWithoutChildren() {
        #expect(versions.leaves.map(\.id) == [second.id, grandchild.id])
    }

    @Test func leavesOfEmptyCollectionAreEmpty() {
        #expect([Version]().leaves.isEmpty)
    }

    @Test func rootsAreNodesWithoutParent() {
        #expect(versions.roots.map(\.id) == [root.id])
    }

    @Test func rootsIncludeNodesWhoseParentIsMissing() {
        #expect([first, grandchild].roots.map(\.id) == [first.id])
    }

    @Test func subscriptFindsNodeByID() {
        #expect(versions[id: second.id]?.id == second.id)
    }

    @Test func subscriptIsNilForMissingID() {
        #expect(versions[id: UUID()] == nil)
    }
}
#endif
