import SwiftUI
import Testing
@testable import Composition

@MainActor
@Suite struct LabelTests {

    @Test func initAcceptsItem() {
        _ = Label(SampleAction.share)
    }

    @Test func initAcceptsItemWithCustomIcon() {
        _ = Label(SampleStatus.online)
    }

    @Test func initAcceptsTitleAndIcon() {
        _ = Label("Favorite") { Image(systemName: "star") }
    }

    @Test func initAcceptsTitleAndNonImageIcon() {
        _ = Label("") { Circle() }
    }
}
