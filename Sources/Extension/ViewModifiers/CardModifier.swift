import SwiftUI

/// Wraps content in a padded, rounded card with a subtle shadow.
///
/// Apply it with the `cardStyle()` shortcut defined in `View.swift`.
///
/// Minimums are set by `Material` (watchOS 10) and `background(_:in:)` (iOS 15, macOS 12, tvOS 15).
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 10.0, *)
public struct CardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    public init(cornerRadius: CGFloat = 12, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

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
