// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Versioned.swift
// dependencies: [Protocols/Digestible.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

/// A type whose versions are identified by id, each committed with its content's checksum and the id of the version it was forked from.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Versioned: Digestible, Identifiable where ID == UUID {

    /// The identity of this version, which `fork()` replaces with a new random value and `digest(into:)` must leave out.
    var id: UUID { get set }

    /// The commit recording this version's content and parent, or `nil` before the first commit, which `digest(into:)` must leave out.
    var revision: Commit? { get set }

    /// Returns a new instance with only the parent's content, leaving the id and revision to `fork()`.
    static func forked(copying parent: Self) -> Self
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Versioned {

    /// A Boolean value indicating whether the content differs from its revision or the value has never been committed.
    var hasUncommittedChanges: Bool {
        revision?.checksum != checksum
    }

    /// Records the current content in the revision, keeping its parent, and returns the result.
    @discardableResult
    mutating func commit() -> Self {
        let content = checksum
        if content != revision?.checksum {
            revision = Commit(checksum: content, parent: revision?.parent)
        }
        return self
    }

    /// Commits this value, then returns a new version with its content, a new id and this value as its parent.
    mutating func fork() -> Self {
        commit()
        var child = Self.forked(copying: self)
        child.id = UUID()
        child.revision = Commit(checksum: child.checksum, parent: id)
        return child
    }

    /// Returns a Boolean value indicating whether the value was forked from the parent and neither has uncommitted changes.
    func isChild(of parent: Self) -> Bool {
        revision?.parent == parent.id && !hasUncommittedChanges && !parent.hasUncommittedChanges
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Versioned {

    /// The lines of committed values from their oldest reachable ancestor to their newest, the branch with the most values first and ties ordered by the newest value's id.
    var branches: [Branch<Element>] {
        let versions = Dictionary(filter { $0.revision != nil }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let parents = Set(versions.values.compactMap { $0.revision?.parent })
        let heads = versions.values.filter { !parents.contains($0.id) }.sorted { $0.id.uuidString < $1.id.uuidString }
        let branches: [Branch<Element>] = heads.map { head in
            var values = [head]
            var visited: Set<UUID> = [head.id]
            while let parent = values.last?.revision?.parent, let value = versions[parent], visited.insert(parent).inserted {
                values.append(value)
            }
            return Branch(values: values.reversed())
        }
        return branches.sorted { $0.count > $1.count }
    }

    /// The values whose id an earlier value in the collection already has, so they can be deleted.
    var duplicates: [Element] {
        var ids: Set<UUID> = []
        return filter { !ids.insert($0.id).inserted }
    }

    /// The values that have never been committed, so no branch can hold them.
    var uncommitted: [Element] {
        filter { $0.revision == nil }
    }
}

/// A line of committed values from the oldest reachable ancestor to the newest.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Branch<V: Versioned>: RandomAccessCollection {

    private let values: [V]

    fileprivate init(values: [V]) {
        self.values = values
    }

    /// The position one past the last value.
    public var endIndex: Int {
        values.endIndex
    }

    /// A Boolean value indicating whether the branch reaches back to a first version, with no ancestor missing.
    public var isComplete: Bool {
        values.first?.revision?.parent == nil
    }

    /// The position of the oldest value.
    public var startIndex: Int {
        values.startIndex
    }

    /// Accesses the value at the position, ordered from oldest to newest.
    public subscript(position: Int) -> V {
        values[position]
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Branch: Equatable where V: Equatable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Branch: Sendable where V: Sendable {}

/// A record of a version's content and the version it was forked from, made only by `commit()` and `fork()`.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Commit: Codable, Hashable, Sendable {

    /// The checksum of the content when it was committed.
    public let checksum: Checksum

    /// The id of the version this one was forked from, or `nil` for a first version.
    public let parent: UUID?

    fileprivate init(checksum: Checksum, parent: UUID?) {
        self.checksum = checksum
        self.parent = parent
    }
}
#endif
