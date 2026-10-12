// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentable.swift
// dependencies: []

#if canImport(Foundation) && canImport(UniformTypeIdentifiers)
import Foundation
import UniformTypeIdentifiers

/// A type that `FileStorage` keeps in a file of its own format, such as UTF-8 text, instead of as JSON.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol FileRepresentable {

    /// The kind of file the value is kept in, whose preferred extension a path without one gets, such as "txt" for plain text.
    static var contentType: UTType { get }

    /// Creates the value from a file's contents, throwing when they aren't in the type's format.
    init(fileContents: Data) throws

    /// Returns the value as the contents of a file.
    func fileContents() throws -> Data
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Data: FileRepresentable {

    /// Bytes in no particular format, as a dynamic type that needs no registration and prefers the "data" extension.
    public static var contentType: UTType { UTType(tag: "data", tagClass: .filenameExtension, conformingTo: .data) ?? .data }

    /// Creates the data from a file's contents, exactly as they are.
    public init(fileContents: Data) {
        self = fileContents
    }

    /// Returns the data exactly as it is.
    public func fileContents() -> Data {
        self
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Optional: FileRepresentable where Wrapped: FileRepresentable {

    /// The wrapped type's content type.
    public static var contentType: UTType { Wrapped.contentType }

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

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension String: FileRepresentable {

    /// Plain text, which prefers the "txt" extension.
    public static var contentType: UTType { .plainText }

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
