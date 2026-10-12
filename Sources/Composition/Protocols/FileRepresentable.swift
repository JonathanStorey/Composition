// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentable.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

/// A type that `FileStorage` keeps in a file of its own format, such as UTF-8 text, instead of as JSON.
public protocol FileRepresentable {

    /// The extension a file gets when its path has none, such as "txt".
    static var preferredFilenameExtension: String { get }

    /// Creates the value from a file's contents, throwing when they aren't in the type's format.
    init(fileContents: Data) throws

    /// Returns the value as the contents of a file.
    func fileContents() throws -> Data
}

extension Data: FileRepresentable {

    /// The extension for bytes in no particular format.
    public static var preferredFilenameExtension: String { "data" }

    /// Creates the data from a file's contents, exactly as they are.
    public init(fileContents: Data) {
        self = fileContents
    }

    /// Returns the data exactly as it is.
    public func fileContents() -> Data {
        self
    }
}

extension Optional: FileRepresentable where Wrapped: FileRepresentable {

    /// The wrapped type's extension.
    public static var preferredFilenameExtension: String { Wrapped.preferredFilenameExtension }

    /// Creates the wrapped value from a file's contents.
    public init(fileContents: Data) throws {
        self = try Wrapped(fileContents: fileContents)
    }

    /// Returns the wrapped value's contents, throwing for `nil`, which has no file.
    public func fileContents() throws -> Data {
        guard let wrapped: Wrapped = self else { throw CocoaError(.fileNoSuchFile) }
        return try wrapped.fileContents()
    }
}

extension String: FileRepresentable {

    /// The extension for plain text.
    public static var preferredFilenameExtension: String { "txt" }

    /// Creates the string from UTF-8 text.
    public init(fileContents: Data) throws {
        guard let string: String = String(data: fileContents, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        self = string
    }

    /// Returns the string as UTF-8 text.
    public func fileContents() -> Data {
        Data(utf8)
    }
}
#endif
