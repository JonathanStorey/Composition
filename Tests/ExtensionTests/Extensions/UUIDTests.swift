import Foundation
import Testing
@testable import Extension

@Suite struct UUIDTests {

    @Test func timeStampEmbedsCurrentTime() {
        let before = UInt64(Date().timeIntervalSince1970 * 1000)
        let uuid = UUID.timeStamp
        let after = UInt64(Date().timeIntervalSince1970 * 1000)

        let bytes = uuid.uuid
        let embedded = [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5]
            .reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        #expect((before...after).contains(embedded))
    }

    @Test func timeStampIsUnique() {
        #expect(UUID.timeStamp != UUID.timeStamp)
    }

    @Test func timeStampSetsVersionAndVariant() {
        let characters = Array(UUID.timeStamp.uuidString)
        #expect(characters[14] == "7")
        #expect("89AB".contains(characters[19]))
    }
}
