#if canImport(Foundation)
import Foundation

public extension JSONDecoder {

    /// Decodes a value from JSON written in the compatibility target's format, ignoring this decoder's own settings.
    func decode<D: Decodable>(_ type: D.Type, from data: Data, compatibility: JSONEncoder.Compatibility) throws -> D {
        let decoder = JSONDecoder()
        switch compatibility {
        case .python:
            decoder.allowsJSON5 = true
            decoder.dateDecodingStrategy = .custom { dateDecoder in
                let microseconds = try dateDecoder.singleValueContainer().decode(Int64.self)
                return Date(timeIntervalSince1970: Double(microseconds) / 1_000_000)
            }
        }
        return try decoder.decode(type, from: data)
    }
}
#endif
