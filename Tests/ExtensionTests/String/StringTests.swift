import Testing
@testable import Extension

@Suite struct StringTests {
    @Test func trimmedRemovesSurroundingWhitespace() {
        #expect("  Hello, world!\n".trimmed == "Hello, world!")
        #expect("no-op".trimmed == "no-op")
    }

    @Test func isBlankDetectsEmptyAndWhitespaceOnly() {
        #expect("".isBlank)
        #expect(" \t\n".isBlank)
        #expect(!" a ".isBlank)
    }
}
