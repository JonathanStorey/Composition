import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Button where Label == SwiftUI.Label<Text, Image> {

    /// Creates a button labeled with the item's title and symbol, using the item's role.
    init(_ item: some LabelRepresentable, action: @escaping @MainActor () -> Void) {
        self.init(role: item.role, action: action) {
            SwiftUI.Label(item)
        }
    }
}
