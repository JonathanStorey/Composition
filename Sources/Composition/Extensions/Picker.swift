// repository: https://github.com/JonathanStorey/Composition
// path: Extensions/Picker.swift
// dependencies: [Extensions/Label.swift, Protocols/LabelRepresentable.swift]

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Picker where Label == Text, SelectionValue: CaseIterable & LabelRepresentable, Content == ForEach<[SelectionValue], SelectionValue, SwiftUI.Label<Text, SelectionValue.Icon>> {

    /// Creates a picker with one labeled option for every case of the selection type.
    init(_ title: LocalizedStringResource, selection: Binding<SelectionValue>) {
        self.init(selection: selection, content: { ForEach(Array(SelectionValue.allCases), id: \.self) { SwiftUI.Label($0) } }, label: { Text(title) })
    }
}
#endif
