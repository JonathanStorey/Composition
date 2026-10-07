import SwiftUI
import Testing
@testable import Extension

@MainActor
@Suite struct PickerTests {

    @Test func initAcceptsCaseIterableItem() {
        _ = Picker("Action", selection: .constant(SampleAction.archive))
    }
}
