import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    @Published var pendingNotifications: [UNNotificationRequest] = []
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    // Default end-of-day summary time: 9:30 PM
    private var summaryHour: Int = 21
    private var summaryMinute: Int = 30

    init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - End-of-Day Summary

    func setSummaryTime(hour: Int, minute: Int) {
        summaryHour = hour
        summaryMinute = minute
        UserDefaults.standard.set(hour, forKey: "summary_hour")
        UserDefaults.standard.set(minute, forKey: "summary_minute")
    }

    func loadSavedSummaryTime() {
        if UserDefaults.standard.object(forKey: "summary_hour") != nil {
            summaryHour = UserDefaults.standard.integer(forKey: "summary_hour")
            summaryMinute = UserDefaults.standard.integer(forKey: "summary_minute")
        }
    }

    var summaryTimeComponents: DateComponents {
        var components = DateComponents()
        components.hour = summaryHour
        components.minute = summaryMinute
        return components
    }

    func scheduleEndOfDaySummary() async throws {
        // Remove any existing summary notification
        cancelEndOfDaySummary()

        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "Review your reminders and prepare for tomorrow"
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"

        // Create trigger for daily notification
        var dateComponents = DateComponents()
        dateComponents.hour = summaryHour
        dateComponents.minute = summaryMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_summary",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        await updatePendingNotifications()
    }

    func cancelEndOfDaySummary() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_summary"])
    }

    func triggerImmediateSummary() async {
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "Your end-of-day summary is ready"
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "immediate_summary_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to trigger immediate summary: \(error)")
        }
    }

    // MARK: - Reminder Notifications

    func scheduleReminderNotification(_ reminder: VoiceReminder, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = reminder.transcription.prefix(100) + (reminder.transcription.count > 100 ? "..." : "")
        content.sound = .default
        content.categoryIdentifier = "VOICE_REMINDER"
        content.userInfo = ["reminder_id": reminder.id]

        if let clientName = reminder.clientName {
            content.subtitle = clientName
        }

        // Set badge based on priority
        if reminder.priority == .critical || reminder.priority == .high {
            content.interruptionLevel = .timeSensitive
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "reminder_\(reminder.id)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        await updatePendingNotifications()
    }

    func cancelReminder(_ reminderId: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder_\(reminderId)"])
    }

    // MARK: - Session Reminder

    func scheduleSessionReminder(for appointment: Appointment, minutesBefore: Int = 15) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Session"
        content.body = "\(appointment.title) in \(minutesBefore) minutes"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"
        content.userInfo = ["appointment_id": appointment.id]

        let reminderDate = appointment.scheduledAt.addingTimeInterval(-Double(minutesBefore * 60))

        guard reminderDate > Date() else {
            return // Don't schedule for past times
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "session_\(appointment.id)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelSessionReminder(_ appointmentId: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["session_\(appointmentId)"])
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        Task {
            do {
                try await center.setBadgeCount(count)
            } catch {
                print("Failed to set badge count: \(error)")
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }

    // MARK: - Helpers

    func updatePendingNotifications() async {
        pendingNotifications = await center.pendingNotificationRequests()
    }

    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
        pendingNotifications = []
    }

    // MARK: - Notification Categories

    func registerCategories() {
        // Daily summary actions
        let viewSummaryAction = UNNotificationAction(
            identifier: "VIEW_SUMMARY",
            title: "View Summary",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze",
            options: []
        )
        let summaryCategory = UNNotificationCategory(
            identifier: "DAILY_SUMMARY",
            actions: [viewSummaryAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Voice reminder actions
        let markCompleteAction = UNNotificationAction(
            identifier: "MARK_COMPLETE",
            title: "Complete",
            options: []
        )
        let addToPrepAction = UNNotificationAction(
            identifier: "ADD_TO_PREP",
            title: "Add to Session Prep",
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "VOICE_REMINDER",
            actions: [markCompleteAction, addToPrepAction],
            intentIdentifiers: [],
            options: []
        )

        // Session reminder actions
        let viewPrepAction = UNNotificationAction(
            identifier: "VIEW_PREP",
            title: "View Prep",
            options: .foreground
        )
        let sessionCategory = UNNotificationCategory(
            identifier: "SESSION_REMINDER",
            actions: [viewPrepAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([summaryCategory, reminderCategory, sessionCategory])
    }
}
