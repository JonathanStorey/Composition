import Testing
@testable import Extension

@Test func versionIsSet() {
    #expect(!Extension.version.isEmpty)
}
