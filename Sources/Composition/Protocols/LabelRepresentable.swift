// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/LabelRepresentable.swift
// dependencies: []

#if canImport(SwiftUI)
import SwiftUI

/// A type that supplies the title, icon, role, and help text used to build a label, button, or picker option.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol LabelRepresentable<Icon> {

    /// The type of view shown as the icon.
    associatedtype Icon: View = Image

    /// The localized tooltip or accessibility hint, or `nil` for none.
    var help: LocalizedStringResource? { get }

    /// The view shown as the icon, such as an SF Symbol, an asset image, or any other view.
    @ViewBuilder var icon: Icon { get }

    /// The button role, such as `.destructive`, or `nil` for a standard button.
    var role: ButtonRole? { get }

    /// The localized text shown as the title.
    var title: LocalizedStringResource { get }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension LabelRepresentable {

    /// No help text by default.
    var help: LocalizedStringResource? { nil }

    /// No role by default.
    var role: ButtonRole? { nil }
}
#endif
