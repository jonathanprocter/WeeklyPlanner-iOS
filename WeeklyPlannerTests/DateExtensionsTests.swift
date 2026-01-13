import XCTest
@testable import WeeklyPlanner

final class DateExtensionsTests: XCTestCase {
    private var originalTimeZone: TimeZone?

    override func setUp() {
        super.setUp()
        originalTimeZone = TimeZone.ReferenceType.default
        TimeZone.ReferenceType.default = TimeZone(secondsFromGMT: 0) ?? .current
    }

    override func tearDown() {
        if let originalTimeZone {
            TimeZone.ReferenceType.default = originalTimeZone
        }
        super.tearDown()
    }

    func testStartOfWeekIsMonday() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let components = DateComponents(calendar: calendar, year: 2025, month: 1, day: 15)
        let date = calendar.date(from: components) ?? Date()

        let startOfWeek = date.startOfWeek
        let weekday = calendar.component(.weekday, from: startOfWeek)

        XCTAssertEqual(weekday, 2)
    }

    func testDateStringFormat() {
        let calendar = Calendar.current
        let components = DateComponents(calendar: calendar, year: 2024, month: 12, day: 31)
        let date = calendar.date(from: components) ?? Date()

        XCTAssertEqual(date.dateString, "2024-12-31")
    }
}
