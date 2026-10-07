import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension Picker
where Label == Text,
      SelectionValue: CaseIterable & LabelRepresentable,
      Content == ForEach<[SelectionValue], SelectionValue, SwiftUI.Label<Text, SelectionValue.Icon>> {

    /// Creates a picker with one labeled option for every case of the selection type.
    init(_ title: LocalizedStringResource, selection: Binding<SelectionValue>) {
        self.init(selection: selection) {
            ForEach(Array(SelectionValue.allCases), id: \.self) { option in
                SwiftUI.Label(option)
            }
        } label: {
            Text(title)
        }
    }
}
