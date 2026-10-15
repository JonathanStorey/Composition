// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/ChildRecords.swift
// dependencies: [Protocols/CKRecordable.swift]

#if canImport(CloudKit)
import CloudKit

/// An array or set of values that each keep a record of their own, whose parent is the record holding the collection.
protocol ChildRecords: Collection where Element: CKRecordable & Codable & Identifiable, Element.ID: CustomStringConvertible & Decodable {

    /// Creates the collection from its children.
    init(_ children: [Element])
}

extension Array: ChildRecords where Element: CKRecordable & Codable & Identifiable, Element.ID: CustomStringConvertible & Decodable {}

extension Set: ChildRecords where Element: CKRecordable & Codable & Identifiable, Element.ID: CustomStringConvertible & Decodable {}
#endif
