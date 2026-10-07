import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Label where Title == Text, Icon == Image {

    /// Creates a label from the item's title and symbol.
    init(_ item: some LabelRepresentable) {
        self.init {
            Text(item.title)
        } icon: {
            Image(systemName: item.systemImage)
        }
    }
}
