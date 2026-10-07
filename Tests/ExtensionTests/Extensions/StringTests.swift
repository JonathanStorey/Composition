import Testing
@testable import Extension

@Suite struct StringTests {

    @Test func isBlankDetectsEmptyAndWhitespaceOnly() {
        #expect("".isBlank)
        #expect(" \t\n".isBlank)
        #expect(!" a ".isBlank)
    }

    @Test func matchesPatternRequiresWholeMatch() {
        #expect("2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#))
        #expect(!"Due 2026-10-07".matches(pattern: #"\d{4}-\d{2}-\d{2}"#))
    }

    @Test func matchesPatternReturnsFalseForInvalidPattern() {
        #expect(!"abc".matches(pattern: "("))
    }

    @Test func trimmedRemovesSurroundingWhitespace() {
        #expect("  Hello, world!\n".trimmed == "Hello, world!")
        #expect("no-op".trimmed == "no-op")
    }
}
