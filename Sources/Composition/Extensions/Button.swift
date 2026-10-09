// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/Button.swift
// dependencies: [Extensions/Label.swift, Protocols/LabelRepresentable.swift]

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Button {

    /// Creates a button labeled with the label's title and icon, using the label's role.
    init<L: LabelRepresentable>(_ label: L, action: @escaping @MainActor () -> Void) where Label == SwiftUI.Label<Text, L.Icon> {
        self.init(role: label.role, action: action) {
            SwiftUI.Label(label)
        }
    }
}
#endif
