/// Keeps a value within a closed range by pulling out-of-range values to the nearest bound.
@propertyWrapper
public struct Clamped<Value: Comparable> {

    /// The range the value is kept within.
    public let range: ClosedRange<Value>
    private var value: Value

    /// Creates a wrapper that clamps the initial value and all later values to the range.
    public init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    /// The clamped value.
    public var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

extension Clamped: Sendable where Value: Sendable {}
