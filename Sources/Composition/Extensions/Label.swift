import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Label where Title == Text {

    /// Creates a label from the item's title and icon.
    init<L: LabelRepresentable>(_ label: L) where Icon == L.Icon {
        self.init(label.title) {
            label.icon
        }
    }
}
