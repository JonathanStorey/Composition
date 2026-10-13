
protocol RecordRepresentable {

    init(from record: CKRecord) throws

    func record<ID: LosslessStringConvertible>(type recordType: String, id recordID: KeyPath<Self, ID>? =nil, zone: String? = nil) throws -> Self

}

internal extension Codable: RecordRepresentable {

    func record<ID: LosslessStringConvertible>(type: String) throws -> Self {
        let record = CKRecord(recordType: type)
        record[data] = JSONEncoder().encode(self)
    }
}

internal extension Codable & Indentifiable: RecordRepresentable {

    func record<ID: LosslessStringConvertible>(type recordType: String, id recordID: /.id) throws -> Self {
        let record = CKRecord(recordType: type, recordID: keyPath: /.id)
        record[data] = JSONEncoder().encode(self)
    }
}
