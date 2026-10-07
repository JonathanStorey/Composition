import SwiftUI
import Testing
@testable import Extension

@MainActor
@Suite struct LabelTests {

    @Test func initAcceptsItem() {
        _ = Label(SampleAction.share)
    }
}
