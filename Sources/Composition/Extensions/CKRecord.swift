// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/CKRecord.swift
// dependencies: [Extensions/CKRecordZone.swift]

#if canImport(CloudKit)
import CloudKit

public extension CKRecord {

    /// The record type that keeps values of the type: its name with each run of other characters replaced by one underscore, as in `Box_Int` for `Box<Int>`.
    static func recordType<T>(of type: T.Type) -> CKRecord.RecordType {
        String(describing: type).split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "_")
    }
}

public extension CKRecord.ID {

    /// Creates the identifier of the record that keeps a value of the type under the key, named `Type.key`, or `Type` when the key is nil, throwing when CloudKit would reject the name.
    convenience init<T>(for type: T.Type, key: String?, zoneID: CKRecordZone.ID = .defaultZone) throws {
        let name: String = [CKRecord.recordType(of: type), key].compactMap { $0 }.joined(separator: ".")
        guard name.count <= 255, name.allSatisfy(\.isASCII) else { throw EncodingError.invalidValue(name, EncodingError.Context(codingPath: [], debugDescription: "CloudKit needs a record name of at most 255 ASCII characters, unlike \"\(name)\".")) }
        self.init(recordName: name, zoneID: zoneID)
    }

    /// The key after the type in the record name, or nil when the name is the type alone, throwing when the name belongs to another type.
    func key<T>(for type: T.Type) throws -> String? {
        let recordType: CKRecord.RecordType = CKRecord.recordType(of: type)
        if recordName == recordType { return nil }
        guard recordName.hasPrefix("\(recordType).") else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The record named \"\(recordName)\" doesn't keep a \(recordType).")) }
        return String(recordName.dropFirst(recordType.count + 1))
    }
}
#endif
