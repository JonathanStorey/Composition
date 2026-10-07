import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 10.0, *)
public extension View {

    /// Styles the view as a padded, rounded card with a subtle shadow.
    func cardStyle(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
