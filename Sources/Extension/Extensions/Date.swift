import Foundation

public extension Date {

    /// A Boolean value indicating whether the date falls within today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// A Boolean value indicating whether the date falls within tomorrow.
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// A Boolean value indicating whether the date falls within yesterday.
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// The start of today in the current calendar.
    static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// The start of tomorrow in the current calendar.
    static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
    }

    /// The start of yesterday in the current calendar.
    static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86_400)
    }
}
