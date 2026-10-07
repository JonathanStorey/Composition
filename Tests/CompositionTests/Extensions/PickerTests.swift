import SwiftUI
import Testing
@testable import Composition

@MainActor
@Suite struct PickerTests {

    @Test func initAcceptsCaseIterableItem() {
        _ = Picker("Action", selection: .constant(SampleAction.archive))
    }

    @Test func initAcceptsCaseIterableItemWithCustomIcon() {
        _ = Picker("Status", selection: .constant(SampleStatus.online))
    }
}
