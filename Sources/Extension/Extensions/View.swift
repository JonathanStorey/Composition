// Requires CardModifier.swift (in ViewModifiers) alongside this file.

import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 10.0, *)
public extension View {
    /// Styles the view as a card. Shortcut for `.modifier(CardModifier(...))`.
    ///
    ///     Text("Hello").cardStyle()
    func cardStyle(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
