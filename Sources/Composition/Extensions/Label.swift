import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Label where Title == Text {

    /// Creates a label from the label's title and icon.
    init<L: LabelRepresentable>(_ label: L) where Icon == L.Icon {
        self.init(label.title) {
            label.icon
        }
    }

    /// Creates a label with a localized title and a custom icon.
    init(_ title: LocalizedStringResource, @ViewBuilder icon: () -> Icon) {
        self.init(title: { Text(title) }, icon: icon)
    }
}
