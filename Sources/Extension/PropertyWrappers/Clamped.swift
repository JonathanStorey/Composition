// Standalone file: paste it into any Swift project. It has no package dependencies.

/// Keeps a value within a closed range. Out-of-range values are pulled to the nearest bound.
///
///     struct Settings {
///         @Clamped(0...100) var volume = 50
///     }
///
///     settings.volume = 150 // stored as 100
///     settings.volume = -5  // stored as 0
///
/// Requires: Swift 5.1+. Standard library only, so it works on every platform.
@propertyWrapper
public struct Clamped<Value: Comparable> {
    private var value: Value
    public let range: ClosedRange<Value>

    public init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    public var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

extension Clamped: Sendable where Value: Sendable {}
