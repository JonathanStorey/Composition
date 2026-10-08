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

    /// Returns a commit of the current content made on the parent's revision, or a first commit when there is no parent.
    func commit(onto parent: Self? = nil) throws -> Commit {
        try Commit(content: self, parent: parent, repository: repository)
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
