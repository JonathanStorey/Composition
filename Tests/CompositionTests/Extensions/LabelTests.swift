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
}
