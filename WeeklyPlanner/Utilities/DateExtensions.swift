import Foundation

extension Date {
    /// Returns the start of the week (Monday)
    var startOfWeek: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: self) ?? self
    }

    /// Returns the end of the week (Sunday)
    var endOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    /// Returns a formatted date string
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    /// Returns date in YYYY-MM-DD format
    var dateString: String {
        formatted("yyyy-MM-dd")
    }

    /// Returns time in h:mm a format
    var timeString: String {
        formatted("h:mm a")
    }

    /// Returns full date and time
    var fullString: String {
        formatted("EEEE, MMMM d, yyyy 'at' h:mm a")
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Check if date is in current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Add days to date
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add hours to date
    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    /// Get hour component
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// Get minute component
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    /// Create date with specific hour and minute
    func with(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }
}
