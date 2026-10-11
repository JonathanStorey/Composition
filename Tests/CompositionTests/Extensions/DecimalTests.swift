// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/DecimalTests.swift
// dependencies: [Extensions/Decimal.swift]

#if canImport(Foundation)
import Foundation
import Testing
@testable import Composition

@Suite struct DecimalTests {

    @Test func normalizedDescriptionDropsTrailingZeros() throws {
        let decimal: Decimal = try #require(Decimal(string: "1.50"))
        #expect(decimal.normalizedDescription == "1.5")
    }

    @Test func normalizedDescriptionKeepsIntegerZeros() throws {
        let decimal: Decimal = try #require(Decimal(string: "100"))
        #expect(decimal.normalizedDescription == "100")
    }

    @Test func normalizedDescriptionReducesZeroFractionToZero() throws {
        let decimal: Decimal = try #require(Decimal(string: "0.000"))
        #expect(decimal.normalizedDescription == "0")
    }
}
#endif
