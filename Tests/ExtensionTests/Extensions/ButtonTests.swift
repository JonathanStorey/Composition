import SwiftUI
import Testing
@testable import Extension

@MainActor
@Suite struct ButtonTests {

    @Test func initAcceptsItemWithCustomIcon() {
        _ = Button(SampleStatus.offline) {}
    }

    @Test func initAcceptsItemWithDefaultRole() {
        _ = Button(SampleAction.share) {}
    }

    @Test func initAcceptsItemWithDestructiveRole() {
        _ = Button(SampleAction.delete) {}
    }
}
