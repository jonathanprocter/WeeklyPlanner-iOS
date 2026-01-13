import Foundation
import Combine

@MainActor
class CalendarSyncViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var isSyncing = false
    @Published var calendars: [GoogleCalendar] = []
    @Published var selectedCalendarIds: Set<String> = []
    @Published var lastSyncTime: Date?
    @Published var syncProgress: (current: Int, total: Int, calendar: String) = (0, 0, "")
    @Published var error: String?

    private let googleService = GoogleCalendarService.shared
    private let apiClient = APIClient.shared

    init() {
        isSignedIn = googleService.isSignedIn
    }

    func signIn() async {
        do {
            try await googleService.signIn()
            isSignedIn = true
            await loadCalendars()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        googleService.signOut()
        isSignedIn = false
        calendars = []
        selectedCalendarIds = []
    }

    func loadCalendars() async {
        do {
            calendars = try await googleService.fetchCalendarList()
            // Select all calendars by default
            selectedCalendarIds = Set(calendars.map { $0.id })
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleCalendar(_ calendarId: String) {
        if selectedCalendarIds.contains(calendarId) {
            selectedCalendarIds.remove(calendarId)
        } else {
            selectedCalendarIds.insert(calendarId)
        }
    }

    func syncCalendars() async {
        guard !selectedCalendarIds.isEmpty else {
            error = "No calendars selected"
            return
        }

        isSyncing = true
        error = nil

        let calendarsToSync = calendars.filter { selectedCalendarIds.contains($0.id) }
        var allEvents: [[String: Any]] = []

        // Sync date range: 2015-2030 (matching web app)
        let startDate = DateComponents(calendar: .current, year: 2015, month: 1, day: 1).date ?? Date()
        let endDate = DateComponents(calendar: .current, year: 2030, month: 12, day: 31).date ?? Date()

        for (index, calendar) in calendarsToSync.enumerated() {
            syncProgress = (index + 1, calendarsToSync.count, calendar.summary)

            do {
                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                let events = try await googleService.fetchEvents(
                    calendarId: calendar.id,
                    from: startDate,
                    to: endDate
                )

                for event in events {
                    guard let startDateTime = event.start.dateTime ?? event.start.date,
                          let endDateTime = event.end.dateTime ?? event.end.date else {
                        continue
                    }

                    let dateFormatter = DateFormatter()
                    let isAllDay = event.start.date != nil && event.start.dateTime == nil

                    var startTimeDate: Date
                    var endTimeDate: Date
                    var dateStr: String

                    if isAllDay {
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        startTimeDate = dateFormatter.date(from: startDateTime) ?? Date()
                        endTimeDate = dateFormatter.date(from: endDateTime) ?? Date()
                        dateStr = startDateTime
                    } else {
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        startTimeDate = isoFormatter.date(from: startDateTime) ?? Date()
                        endTimeDate = isoFormatter.date(from: endDateTime) ?? Date()

                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        dateStr = dateFormatter.string(from: startTimeDate)
                    }

                    let eventDict: [String: Any] = [
                        "id": event.id,
                        "calendarId": calendar.id,
                        "title": event.summary ?? "Untitled",
                        "date": dateStr,
                        "startTime": ISO8601DateFormatter().string(from: startTimeDate),
                        "endTime": ISO8601DateFormatter().string(from: endTimeDate),
                        "description": event.description ?? "",
                        "location": event.location ?? "",
                        "calendar": calendar.summary,
                        "category": categoryFromColorId(event.colorId)
                    ]

                    allEvents.append(eventDict)
                }

                // Delay between calendars
                if index < calendarsToSync.count - 1 {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                }

            } catch {
                print("Error syncing \(calendar.summary): \(error)")
                // Continue with other calendars
            }
        }

        // Send to backend
        do {
            let result = try await apiClient.syncFromGoogle(events: allEvents)
            print("Synced \(result.synced) events, deleted \(result.deleted)")
            lastSyncTime = Date()
        } catch {
            self.error = "Failed to save to database: \(error.localizedDescription)"
        }

        isSyncing = false
        syncProgress = (0, 0, "")
    }

    private func categoryFromColorId(_ colorId: String?) -> String {
        guard let colorId = colorId, let colorInt = Int(colorId) else {
            return "other"
        }
        let categories = ["work", "personal", "meeting", "other"]
        return categories[colorInt % categories.count]
    }
}
