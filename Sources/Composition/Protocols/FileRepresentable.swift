// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/FileRepresentable.swift
// dependencies: []

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

/// A type that keeps itself in a file of its own format, such as text or CSV, instead of as JSON.
public protocol FileRepresentable {

    /// The extension a file gets when its path has none, such as "txt".
    static var fileExtension: String { get }

    /// Creates the value from a file's contents, throwing when they aren't in the type's format.
    init(fileContents: Data) throws

    /// The value as the contents of a file.
    var fileContents: Data { get throws }
}

extension Array: FileRepresentable where Element == [String] {

    /// The extension for comma-separated values.
    public static var fileExtension: String { "csv" }

    /// Creates the rows of fields from UTF-8 comma-separated values, where a quoted field can hold commas, quotes and line breaks.
    public init(fileContents: Data) throws {
        guard let text: String = String(data: fileContents, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        var rows: [[String]] = []
        var row: [String] = []
        var field: String = ""
        var isQuoted: Bool = false
        var characters: String.Iterator = text.makeIterator()
        while let character: Character = characters.next() {
            switch (isQuoted, character) {
            case (true, "\""):
                guard let next: Character = characters.next() else { isQuoted = false; continue }
                if next == "\"" { field.append(next); continue }
                isQuoted = false
                switch next {
                case ",": row.append(field); field = ""
                case "\n", "\r\n": row.append(field); rows.append(row); row = []; field = ""
                default: field.append(next)
                }
            case (true, _): field.append(character)
            case (false, "\"") where field.isEmpty: isQuoted = true
            case (false, ","): row.append(field); field = ""
            case (false, "\n"), (false, "\r\n"): row.append(field); rows.append(row); row = []; field = ""
            case (false, _): field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        self = rows
    }

    /// The rows as UTF-8 comma-separated values, one line each, quoting a field that holds a comma, quote or line break.
    public var fileContents: Data {
        Data(map { $0.map(Self.escaped).joined(separator: ",") + "\r\n" }.joined().utf8)
    }

    /// The field, quoted with its quotes doubled when it holds a comma, quote or line break.
    private static func escaped(_ field: String) -> String {
        field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) ? "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\"" : field
    }
}

extension Data: FileRepresentable {

    /// The extension for bytes in no particular format.
    public static var fileExtension: String { "data" }

    /// Creates the data from a file's contents, exactly as they are.
    public init(fileContents: Data) {
        self = fileContents
    }

    /// The data, exactly as it is.
    public var fileContents: Data { self }
}

extension Optional: FileRepresentable where Wrapped: FileRepresentable {

    /// The extension of the wrapped type.
    public static var fileExtension: String { Wrapped.fileExtension }

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

extension String: FileRepresentable {

    /// The extension for plain text.
    public static var fileExtension: String { "txt" }

    /// Creates the string from UTF-8 text.
    public init(fileContents: Data) throws {
        guard let string: String = String(data: fileContents, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        self = string
    }

    /// The string as UTF-8 text.
    public var fileContents: Data { Data(utf8) }
}
#endif

// MARK: - AppKit + Foundation

#if canImport(AppKit) && canImport(Foundation) && !targetEnvironment(macCatalyst)
import AppKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension AttributedString: FileRepresentable {

    /// The extension for rich text.
    public static var fileExtension: String { "rtf" }

    /// Creates the styled text from rich text.
    public init(fileContents: Data) throws {
        try self.init(NSAttributedString(data: fileContents, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil), including: \.appKit)
    }

    /// The styled text as rich text.
    public var fileContents: Data {
        get throws {
            let text: NSAttributedString = try NSAttributedString(self, including: \.appKit)
            return try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }
    }
}
#endif

// MARK: - Foundation + UIKit

#if canImport(Foundation) && canImport(UIKit) && !os(watchOS)
import UIKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension AttributedString: FileRepresentable {

    /// The extension for rich text.
    public static var fileExtension: String { "rtf" }

    /// Creates the styled text from rich text.
    public init(fileContents: Data) throws {
        try self.init(NSAttributedString(data: fileContents, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil), including: \.uiKit)
    }

    /// The styled text as rich text.
    public var fileContents: Data {
        get throws {
            let text: NSAttributedString = try NSAttributedString(self, including: \.uiKit)
            return try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }
    }
}
#endif
