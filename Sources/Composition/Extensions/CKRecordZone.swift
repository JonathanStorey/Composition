// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecordZone.swift
// dependencies: []

#if canImport(CloudKit)
import CloudKit

public extension CKRecordZone.ID {

    /// The custom zone named DefaultZone, where the record coders put records unless told otherwise, since only custom zones save atomically.
    static var defaultZone: CKRecordZone.ID { CKRecordZone.ID(zoneName: "DefaultZone") }
}
#endif
