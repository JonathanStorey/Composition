// repository: https://github.com/JonathanStorey/Composition
// path: ViewModifiers/CardModifier.swift
// dependencies: [Extensions/View.swift]

#if canImport(SwiftUI)
import SwiftUI

/// Wraps content in a padded, rounded card with a subtle shadow.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 10.0, *)
public struct CardModifier: ViewModifier {

    private let cornerRadius: CGFloat
    private let padding: CGFloat

    /// Creates a card modifier with the given corner radius and padding.
    public init(cornerRadius: CGFloat = 12, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    /// Applies the card styling to the content.
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Default card")
            .cardStyle()

        Text("Larger corners")
            .cardStyle(cornerRadius: 24, padding: 24)
    }
    .padding()
}
#endif
