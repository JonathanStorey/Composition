// repository: https://github.com/JonathanStorey/Composition
// path: CompositionTests.swift
// dependencies: [Composition.swift]

import Testing
@testable import Composition

@Test func versionIsSet() {
    #expect(!Composition.version.isEmpty)
}
