import SwiftUI

public extension View {
    /// Styles the view as a card. Shortcut for `.modifier(CardModifier(...))`.
    ///
    ///     Text("Hello").cardStyle()
    func cardStyle(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
