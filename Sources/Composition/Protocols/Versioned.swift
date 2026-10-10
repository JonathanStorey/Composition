// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Versioned.swift
// dependencies: [Protocols/Digestible.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

/// A type whose versions are identified by id and committed through a repository, each recording its content's checksum and the id of the version it was forked from.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Versioned: Digestible, Identifiable where ID == UUID {

    /// The identity of this version, which a fork replaces with a new random value.
    var id: UUID { get set }

    /// The commit state of this version, which starts as `Commit()` and which `digest(into:)` must leave out.
    var revision: Commit { get set }

    /// Returns a new instance with only the parent's content, leaving the id and revision to the repository.
    static func forked(copying parent: Self) -> Self
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Versioned {

    /// A Boolean value indicating whether the value has not been committed or its content changed since it was.
    var hasUncommittedChanges: Bool {
        !revision.isCommitted || revision.checksum != checksum
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
fileprivate extension Versioned {

    /// Returns the value with its current content committed, keeping its id and parent.
    func committed() -> Self {
        var value = self
        value.revision = Commit(checksum: checksum, isCommitted: true, parent: revision.parent)
        return value
    }

    /// Returns an uncommitted child with this value's content, a new id and this value as its parent.
    func forked() -> Self {
        var child = Self.forked(copying: self)
        child.id = UUID()
        child.revision = Commit(checksum: child.checksum, isCommitted: false, parent: id)
        return child
    }
}

/// A line of committed versions from the oldest reachable ancestor to the newest.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Branch<V: Versioned>: RandomAccessCollection {

    private let values: [V]

    fileprivate init(values: [V]) {
        self.values = values
    }

    /// The position one past the last version.
    public var endIndex: Int {
        values.endIndex
    }

    /// A Boolean value indicating whether the branch reaches back to a first version, with no ancestor missing.
    public var isComplete: Bool {
        values.first?.revision.parent == nil
    }

    /// The position of the oldest version.
    public var startIndex: Int {
        values.startIndex
    }

    /// Accesses the version at the position, ordered from oldest to newest.
    public subscript(position: Int) -> V {
        values[position]
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Branch: Equatable where V: Equatable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Branch: Sendable where V: Sendable {}

/// The commit state of a version: its content's checksum, whether it was committed, and the id of the version it was forked from.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Commit: Codable, Hashable, Sendable {

    /// The checksum of the content when it was committed or forked, or `nil` for a value that has been neither.
    public let checksum: Checksum?

    /// A Boolean value indicating whether the version was committed rather than only created or forked.
    public let isCommitted: Bool

    /// The id of the version this one was forked from, or `nil` for a first version.
    public let parent: UUID?

    /// Creates the state of a new value that has been neither committed nor forked.
    public init() {
        self.init(checksum: nil, isCommitted: false, parent: nil)
    }

    fileprivate init(checksum: Checksum?, isCommitted: Bool, parent: UUID?) {
        self.checksum = checksum
        self.isCommitted = isCommitted
        self.parent = parent
    }
}

/// A history of versions that commits and forks them and answers questions about their branches and ancestry.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Repository<V: Versioned> {

    /// Every value in the repository, committed or not, in the order they were added.
    public private(set) var values: [V]

    /// Creates a repository holding the values of each collection in order, such as the results of several queries.
    public init(_ values: [V]...) {
        self.values = values.flatMap { $0 }
    }

    /// The lines of committed versions from their oldest reachable ancestor to their newest, the branch with the most versions first and ties ordered by the newest version's id.
    public var branches: [Branch<V>] {
        let versions = versions
        let parents = Set(versions.values.compactMap(\.revision.parent))
        let heads = versions.values.filter { !parents.contains($0.id) }.sorted { $0.id.uuidString < $1.id.uuidString }
        return heads.map { Branch(values: Array(lineage(of: $0, in: versions).reversed())) }.sorted { $0.count > $1.count }
    }

    /// The values whose id an earlier value in the repository already has, so they can be deleted.
    public var duplicates: [V] {
        var ids: Set<UUID> = []
        return values.filter { !ids.insert($0.id).inserted }
    }

    /// The newest version of each branch, in the order of `branches`.
    public var heads: [V] {
        branches.compactMap(\.last)
    }

    /// The values that are new or forked and not yet committed.
    public var uncommitted: [V] {
        values.filter { !$0.revision.isCommitted }
    }

    private var versions: [UUID: V] {
        Dictionary(values.filter(\.revision.isCommitted).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Commits the value's current content, adding it or replacing the uncommitted value with its id, and throws if a committed version's content changed in place.
    @discardableResult
    public mutating func commit(_ value: V) throws -> V {
        guard !value.revision.isCommitted || !value.hasUncommittedChanges else { throw VersionedError.committedValueChanged }
        let committed = value.committed()
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = committed
        } else {
            values.append(committed)
        }
        return committed
    }

    /// Commits the value, then adds and returns an uncommitted child with its content, a new id and the value as its parent.
    public mutating func fork(_ value: V) throws -> V {
        let child = try commit(value).forked()
        values.append(child)
        return child
    }

    /// Returns a Boolean value indicating whether the ancestor is a parent, grandparent or earlier committed version of the descendant.
    public func isAncestor(_ ancestor: V, of descendant: V) -> Bool {
        lineage(of: descendant, in: versions).dropFirst().contains { $0.id == ancestor.id }
    }

    /// Returns the version followed by its committed ancestors, newest first.
    public func log(from head: V) -> [V] {
        lineage(of: head, in: versions)
    }

    /// Returns the nearest version that both versions descend from or are, or `nil` when their histories share none.
    public func mergeBase(of ours: V, and theirs: V) -> V? {
        let versions = versions
        let ids = Set(lineage(of: ours, in: versions).map(\.id))
        return lineage(of: theirs, in: versions).first { ids.contains($0.id) }
    }

    /// Returns the first value with the id, committed or not, or `nil` when the repository has none.
    public func value(for id: UUID) -> V? {
        values.first { $0.id == id }
    }

    private func lineage(of value: V, in versions: [UUID: V]) -> [V] {
        var lineage = [value]
        var visited: Set<UUID> = [value.id]
        while let parent = lineage.last?.revision.parent, let version = versions[parent], visited.insert(parent).inserted {
            lineage.append(version)
        }
        return lineage
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Repository: Sendable where V: Sendable {}

/// An error thrown when a repository cannot commit a value.
public enum VersionedError: Error, Equatable, Sendable {

    /// A committed version's content changed in place instead of in a fork.
    case committedValueChanged
}
#endif
