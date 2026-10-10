// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Versioned.swift
// dependencies: [Protocols/Digestible.swift]

#if canImport(CryptoKit) && canImport(Foundation)
import Foundation

/// A type whose versions are identified by id, each recording its content's checksum and the id of the version it was forked from.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Versioned: Digestible, Identifiable where ID == UUID {

    /// The identity of this version, which a fork replaces with a new random value.
    var id: UUID { get set }

    /// The commit state of this version, which starts as `Commit()` and which `digest(into:)` must leave out.
    var revision: Commit { get set }

    /// Returns a new instance with only the parent's content, leaving the id and revision to whoever forks it.
    static func forked(copying parent: Self) -> Self
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Versioned {

    /// A Boolean value indicating whether the value has not been committed or its content changed since it was.
    var hasUncommittedChanges: Bool {
        !revision.isCommitted || !revision.matches(checksum)
    }
}

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

    init(checksum: Checksum?, isCommitted: Bool, parent: UUID?) {
        self.checksum = checksum
        self.isCommitted = isCommitted
        self.parent = parent
    }

    /// A Boolean value indicating whether the version has been neither committed nor forked.
    public var isEmpty: Bool {
        self == Commit()
    }

    /// A Boolean value indicating whether the version was not forked from another.
    public var isRoot: Bool {
        parent == nil
    }

    /// Returns a Boolean value indicating whether the recorded checksum equals the given one.
    public func matches(_ checksum: Checksum) -> Bool {
        self.checksum == checksum
    }
}
#endif
