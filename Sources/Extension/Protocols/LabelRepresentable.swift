import SwiftUI

/// A type that supplies the title, symbol, role, and help text used to build a label, button, or picker option.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol LabelRepresentable {

    /// The localized tooltip or accessibility hint, or `nil` for none.
    var help: LocalizedStringResource? { get }

    /// The button role, such as `.destructive`, or `nil` for a standard button.
    var role: ButtonRole? { get }

    /// The SF Symbol name shown as the icon.
    var systemImage: String { get }

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
