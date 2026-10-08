#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

/// A type whose content can be committed into a named repository of linked revisions.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Versioned: Digestible, Timestamped {

    /// The name of the repository the value belongs to.
    var repository: String { get }

    /// The commit that stamps the current content, or `nil` before the first commit.
    var revision: Commit? { get }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Versioned {

    /// A Boolean value indicating whether the revision matches the current content and repository.
    var isCommitted: Bool {
        revision?.isIntact(for: self) ?? false
    }

    /// Returns a commit of the current content made on the parent's revision, or a first commit when there is no parent.
    func commit(onto parent: Self? = nil) throws -> Commit {
        try Commit(content: self, parent: parent, repository: repository)
    }

    /// Returns a Boolean value indicating whether the value was committed onto the parent's revision and both are still committed.
    func isChild(of parent: Self) -> Bool {
        guard let revision, let base = parent.revision else { return false }
        return revision.parent == base.hash && repository == parent.repository && isCommitted && parent.isCommitted
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Versioned {

    /// The lines of committed values from their oldest reachable commit to their newest, newest branch first.
    var branches: [Branch<Element>] {
        let commits = Dictionary(compactMap { value in value.revision.map { ($0.hash, value) } }, uniquingKeysWith: { first, _ in first })
        let parents = Set(commits.values.compactMap { $0.revision?.parent })
        let heads = commits.filter { !parents.contains($0.key) }.values.sorted { $0.timestamp.uuidString > $1.timestamp.uuidString }
        return heads.map { head in
            var values = [head]
            var visited: Set<Checksum> = []
            while let parent = values.last?.revision?.parent, visited.insert(parent).inserted, let value = commits[parent] {
                values.append(value)
            }
            return Branch(values: values.reversed())
        }
    }

    /// The values grouped by repository name.
    var repositories: [String: [Element]] {
        Dictionary(grouping: self, by: \.repository)
    }

    /// The values in the named repository.
    subscript(repository name: String) -> [Element] {
        filter { $0.repository == name }
    }
}

/// A line of committed values from the oldest reachable commit to the newest.
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

    /// The name of the repository every value in the branch belongs to.
    public var repository: String {
        values[values.startIndex].repository
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

/// A record of a value's content, its repository, and the commit it was made on.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Commit: Codable, Hashable, Sendable {

    fileprivate let content: Checksum

    /// The checksum of the content, the parent's hash, and the repository name.
    public let hash: Checksum

    fileprivate let parent: Checksum?

    private init(content: Checksum, parent: Checksum?, repository name: String) {
        self.content = content
        self.hash = Self.hash(content: content, parent: parent, repository: name)
        self.parent = parent
    }

    fileprivate init<V: Versioned>(content: V, parent: V?, repository name: String) throws {
        if let parent {
            guard let base = parent.revision else { throw CommitError.uncommittedParent }
            guard parent.repository == name else { throw CommitError.differentRepository }
            guard base.isIntact(for: parent) else { throw CommitError.expiredParent }
        }
        self.init(content: content.checksum, parent: parent?.revision?.hash, repository: name)
    }

    private static func hash(content: Checksum, parent: Checksum?, repository name: String) -> Checksum {
        var digester = Digester()
        digester.combine(content)
        digester.combine(parent)
        digester.combine(name)
        return digester.finalize()
    }

    fileprivate func isIntact<V: Versioned>(for value: V) -> Bool {
        content == value.checksum && hash == Self.hash(content: content, parent: parent, repository: value.repository)
    }
}

/// An error thrown when a value cannot be committed.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum CommitError: Error {

    /// The parent belongs to a different repository.
    case differentRepository

    /// The parent's content or repository changed after its revision was made, so its revision no longer matches it.
    case expiredParent

    /// The parent has no revision, so there is no hash to link to.
    case uncommittedParent
}
#endif
