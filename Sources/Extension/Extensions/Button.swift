import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Button {

    /// Creates a button labeled with the item's title and icon, using the item's role.
    init<Item: LabelRepresentable>(_ item: Item, action: @escaping @MainActor () -> Void)
    where Label == SwiftUI.Label<Text, Item.Icon> {
        self.init(role: item.role, action: action) {
            SwiftUI.Label(item)
        }
    }
}
