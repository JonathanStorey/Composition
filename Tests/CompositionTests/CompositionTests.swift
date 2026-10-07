import Testing
@testable import Composition

@Test func versionIsSet() {
    #expect(!Composition.version.isEmpty)
}
