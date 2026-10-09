// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/ClampedTests.swift
// dependencies: [PropertyWrappers/Clamped.swift]

import Testing
@testable import Composition

private struct Settings {

    @Clamped(0...100) var volume = 50
}

@Suite struct ClampedTests {

    @Test func clampsInitialValue() {
        struct Rating {

            @Clamped(1...5) var stars = 9
        }
        #expect(Rating().stars == 5)
    }

    @Test func clampsToBounds() {
        var settings = Settings()
        settings.volume = 150
        #expect(settings.volume == 100)
        settings.volume = -5
        #expect(settings.volume == 0)
    }

    @Test func keepsInRangeValues() {
        var settings = Settings()
        settings.volume = 75
        #expect(settings.volume == 75)
    }
}
