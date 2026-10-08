#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

/// A type whose content can be committed into revisions linked by hash.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Versioned: Digestible {

    /// The commit that stamps the current content, or `nil` before the first commit, which `digest(into:)` must leave out.
    var revision: Commit? { get set }

    /// Returns a new instance carrying over the fields that make up a version, leaving the revision to `fork(_:)`.
    static func forked(from parent: Self) -> Self
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Versioned {

    /// Whether the value has never been committed, was changed after its commit, or still matches its commit.
    var commitStatus: Commit.Status {
        guard let revision else { return .uncommitted }
        return revision.content == checksum ? .committed : .modified
    }

    /// Applies the changes and commits them onto the current revision, keeping the revision when the content still matches it, and returns the result.
    @discardableResult
    mutating func commit(_ changes: (inout Self) throws -> Void = { _ in }) rethrows -> Self {
        var version = self
        try changes(&version)
        let content = version.checksum
        if content != revision?.content {
            version.revision = Commit(content: content, parent: revision?.hash)
        }
        self = version
        return version
    }

    /// Commits this value, then returns a new instance with the changes applied and committed as its child.
    mutating func fork(_ changes: (inout Self) throws -> Void = { _ in }) rethrows -> Self {
        commit()
        var child = Self.forked(from: self)
        child.revision = revision
        try child.commit(changes)
        return child
    }

    /// Returns a Boolean value indicating whether the value was committed onto the parent's revision and both are still committed.
    func isChild(of parent: Self) -> Bool {
        guard let revision, let base = parent.revision else { return false }
        return revision.parent == base.hash && commitStatus == .committed && parent.commitStatus == .committed
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Versioned {

    /// The lines of values with a revision from their oldest reachable commit to their newest, the branch with the most commits first and ties ordered by the newest commit's hash.
    var branches: [Branch<Element>] {
        let commits = Dictionary(compactMap { value in value.revision.map { ($0.hash, value) } }, uniquingKeysWith: { first, _ in first })
        let parents = Set(commits.values.compactMap { $0.revision?.parent })
        let heads = commits.filter { !parents.contains($0.key) }.sorted { $0.key.bytes.lexicographicallyPrecedes($1.key.bytes) }
        let branches: [Branch<Element>] = heads.map { head in
            var values = [head.value]
            while let parent = values.last?.revision?.parent, let value = commits[parent] {
                values.append(value)
            }
            return Branch(values: values.reversed())
        }
        return branches.sorted { $0.count > $1.count }
    }

    /// The values whose commit an earlier value in the collection already carries, so they can be deleted.
    var duplicates: [Element] {
        var hashes: Set<Checksum> = []
        return filter { value in value.revision.map { !hashes.insert($0.hash).inserted } ?? false }
    }

    /// The values that have never been committed, so no branch can hold them.
    var uncommitted: [Element] {
        filter { $0.revision == nil }
    }
}

/// A line of values with a revision from the oldest reachable commit to the newest.
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

    /// A Boolean value indicating whether the branch reaches back to a root commit, with no ancestor missing.
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

/// A record of a value's content and the commit it was made on.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Commit: Codable, Hashable, Sendable {

    fileprivate let content: Checksum

    /// The hash of the commit this one was made on, or `nil` for a first commit.
    public let parent: Checksum?

    fileprivate init(content: Checksum, parent: Checksum?) {
        self.content = content
        self.parent = parent
    }

    /// The checksum of the content and the parent's hash.
    public var hash: Checksum {
        var digester = Digester()
        digester.combine(content)
        digester.combine(parent)
        return digester.finalize()
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Commit {

    /// Whether a value has never been committed, was changed after its commit, or still matches its commit.
    enum Status: Hashable, Sendable {

        /// The revision matches the current content.
        case committed

        /// The content changed after the revision was made.
        case modified

        /// The value has no revision.
        case uncommitted
    }
}
#endif
