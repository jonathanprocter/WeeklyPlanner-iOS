import XCTest
@testable import WeeklyPlanner

final class APIClientDateParsingTests: XCTestCase {
    func testDecodesISO8601WithFractionalSeconds() throws {
        let json = """
        {
          "id": "session-1",
          "therapistId": "therapist-1",
          "scheduledAt": "2025-01-15T10:30:45.123Z",
          "duration": 50,
          "createdAt": "2025-01-10T12:00:00.000Z"
        }
        """

        let data = Data(json.utf8)
        let appointment = try APIClient.shared.decode(Appointment.self, from: data)

        XCTAssertEqual(appointment.duration, 50)
        XCTAssertEqual(appointment.id, "session-1")
    }

    func testDecodesSimpleDateFormat() throws {
        let json = """
        {
          "id": "session-2",
          "therapistId": "therapist-1",
          "scheduledAt": "2025-01-15",
          "duration": 30,
          "createdAt": "2025-01-10"
        }
        """

        let data = Data(json.utf8)
        let appointment = try APIClient.shared.decode(Appointment.self, from: data)

        XCTAssertEqual(appointment.duration, 30)
        XCTAssertEqual(appointment.id, "session-2")
    }
}
