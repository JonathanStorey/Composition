import Foundation
import Testing
@testable import Extension

@Suite struct DateTests {

    @Test func isTodayRejectsOtherDays() {
        #expect(!Date.yesterday.isToday)
        #expect(!Date.tomorrow.isToday)
    }

    @Test func relativeDaysMatchTheirChecks() {
        #expect(Date.today.isToday)
        #expect(Date.tomorrow.isTomorrow)
        #expect(Date.yesterday.isYesterday)
    }

    @Test func todayIsStartOfDay() {
        #expect(Date.today == Calendar.current.startOfDay(for: Date()))
    }
}
