// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecord.swift
// dependencies: []

#if canImport(CloudKit)
import CloudKit

public extension CKRecord {

    /// The record type that keeps values of the type: its name with each run of other characters replaced by one underscore, as in `Box_Int` for `Box<Int>`.
    static func recordType<T>(of type: T.Type) -> CKRecord.RecordType {
        String(describing: type).split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "_")
    }
}
#endif
