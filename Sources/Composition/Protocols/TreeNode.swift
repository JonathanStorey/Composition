// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/TreeNode.swift
// dependencies: [Protocols/NodeProtocol.swift]

#if canImport(Foundation)
import Foundation

/// A node that refers to at most one parent by its identifier.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol TreeNode: NodeProtocol {

    /// The identifier of the node's parent, or nil for a root.
    var parent: UUID? { get }
}
#endif
