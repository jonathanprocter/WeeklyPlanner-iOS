import Foundation

struct GoogleCalendar: Codable, Identifiable {
    let id: String
    let summary: String
    var selected: Bool = true
}

struct GoogleCalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
    let colorId: String?
    let recurrence: [String]?

    struct GoogleDateTime: Codable {
        let dateTime: String?
        let date: String?
        let timeZone: String?
    }
}

struct SyncResult: Codable {
    let synced: Int
    let deleted: Int
}
