// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/Decimal.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

extension Decimal {

    /// The value in plain notation without trailing fractional zeros, matching Python's `format(d.normalize(), "f")`.
    var normalizedDescription: String {
        guard description.contains(".") else { return description }
        var text = description
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
#endif
