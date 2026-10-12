// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentable.swift
// dependencies: []

#if canImport(Foundation) && canImport(UniformTypeIdentifiers)
import Foundation
import UniformTypeIdentifiers

/// A type that keeps itself in a file of its own content type, such as UTF-8 text, instead of as JSON.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol FileRepresentable {

    /// The most specific content type the value's file contents have.
    static var contentType: UTType { get }

    /// Creates the value from a file's contents, throwing when they aren't of the content type.
    init(fileContents: Data) throws

    /// The value as the contents of a file of the content type.
    var fileContents: Data { get throws }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public extension FileRepresentable {

    /// The extension a file gets when its path has none: the content type's preferred one, or "data" when it has none.
    static var preferredFilenameExtension: String {
        contentType.preferredFilenameExtension ?? "data"
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public extension FileRepresentable where Self: LosslessStringConvertible {

    /// Creates the value from UTF-8 text.
    init(fileContents: Data) throws {
        guard let text: String = String(data: fileContents, encoding: .utf8), let value: Self = Self(text) else { throw CocoaError(.fileReadCorruptFile) }
        self = value
    }

    /// The value as UTF-8 text.
    var fileContents: Data {
        Data(description.utf8)
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Data: FileRepresentable {

    /// Bytes in no particular format, which any content type is.
    public static var contentType: UTType { .data }

    /// Creates the data from a file's contents, exactly as they are.
    public init(fileContents: Data) {
        self = fileContents
    }

    /// The data, exactly as it is.
    public var fileContents: Data { self }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Optional: FileRepresentable where Wrapped: FileRepresentable {

    /// The wrapped type's content type.
    public static var contentType: UTType { Wrapped.contentType }

    /// Creates the wrapped value from a file's contents.
    public init(fileContents: Data) throws {
        self = try Wrapped(fileContents: fileContents)
    }

    /// The wrapped value's contents, throwing for `nil`, which has no file.
    public var fileContents: Data {
        get throws {
            guard let wrapped: Wrapped = self else { throw CocoaError(.fileNoSuchFile) }
            return try wrapped.fileContents
        }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension String: FileRepresentable {

    /// UTF-8 plain text.
    public static var contentType: UTType { .utf8PlainText }
}
#endif
