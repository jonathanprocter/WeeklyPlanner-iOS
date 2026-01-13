import XCTest
@testable import WeeklyPlanner

final class WeeklyPlannerTests: XCTestCase {
    func testAppointmentEndTimeUsesDuration() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let appointment = Appointment(
            id: "session-1",
            clientId: nil,
            therapistId: "therapist-1",
            scheduledAt: startDate,
            duration: 50,
            sessionType: .individual,
            status: .scheduled,
            googleEventId: nil,
            notes: nil,
            hasProgressNotePlaceholder: nil,
            progressNoteStatus: nil,
            isSimplePracticeEvent: nil,
            client: nil,
            createdAt: startDate,
            updatedAt: nil
        )

        let expectedEnd = startDate.addingTimeInterval(50 * 60)
        XCTAssertEqual(appointment.endTime, expectedEnd)
    }
}
