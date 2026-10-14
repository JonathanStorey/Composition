// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/Archived.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

/// Makes a secure-coding object codable by encoding it as keyed-archive data.
@propertyWrapper
public struct Archived<Value: NSObject & NSSecureCoding>: Codable, Hashable {

    /// The archived object.
    public var wrappedValue: Value

    /// Creates a wrapper around the object.
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates the object from its archive, throwing when the archive is corrupt or holds another class.
    public init(from decoder: any Decoder) throws {
        let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()
        let archive: Data = try container.decode(Data.self)
        guard let value: Value = try NSKeyedUnarchiver.unarchivedObject(ofClass: Value.self, from: archive) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "The archive holds no \(Value.self).") }
        self.wrappedValue = value
    }

    /// Encodes the object as its archive.
    public func encode(to encoder: any Encoder) throws {
        var container: any SingleValueEncodingContainer = encoder.singleValueContainer()
        try container.encode(NSKeyedArchiver.archivedData(withRootObject: wrappedValue, requiringSecureCoding: true))
    }
}

extension Archived: Sendable where Value: Sendable {}
#endif
