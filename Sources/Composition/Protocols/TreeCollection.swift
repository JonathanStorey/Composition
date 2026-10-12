// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/TreeCollection.swift
// dependencies: [Protocols/NodeProtocol.swift, Protocols/TreeNode.swift]

#if canImport(Foundation)
import Foundation

/// A collection of tree nodes that can find a node by its identifier and a node's children.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol TreeCollection<Element>: Collection where Element: TreeNode {

    /// Returns the node with the identifier, or nil when the collection holds none.
    subscript(id id: UUID) -> Element? { get }

    /// Returns the nodes whose parent is the node.
    func children(of node: Element) -> [Element]
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension TreeCollection {

    /// The nodes that no other node names as its parent.
    var leaves: [Element] {
        let parents: Set<UUID> = Set(compactMap(\.parent))
        return filter { !parents.contains($0.id) }
    }

    /// The nodes whose parent is nil or missing from the collection.
    var roots: [Element] {
        let ids: Set<UUID> = Set(map(\.id))
        return filter { node in node.parent.map { !ids.contains($0) } ?? true }
    }

    /// Returns the node with the identifier by searching every node.
    subscript(id id: UUID) -> Element? {
        first { $0.id == id }
    }

    /// Returns the node's ancestors, from its parent up to its root, stopping at a missing parent or a cycle.
    func ancestors(of node: Element) -> [Element] {
        var ancestors: [Element] = []
        var parent: UUID? = node.parent
        while let id = parent, ancestors.count < count, let ancestor = self[id: id] {
            ancestors.append(ancestor)
            parent = ancestor.parent
        }
        return ancestors
    }

    /// Returns the nodes whose parent is the node by searching every node.
    func children(of node: Element) -> [Element] {
        filter { $0.parent == node.id }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Array: TreeCollection where Element: TreeNode {}
#endif
