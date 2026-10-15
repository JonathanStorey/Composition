// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/CKRecordable.swift
// dependencies: []

/// A value that keeps a CloudKit record of its own, named by an identifier that reads back from its description.
public protocol CKRecordable: Codable, Identifiable where ID: LosslessStringConvertible {}
