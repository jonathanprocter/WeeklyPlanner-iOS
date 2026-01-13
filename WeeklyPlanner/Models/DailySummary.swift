import Foundation

// MARK: - Daily Summary

struct DailySummary: Codable, Identifiable {
    let id: String
    let therapistId: String
    let date: Date
    var reminders: [VoiceReminder]
    var completedSessions: [AppointmentSummary]
    var upcomingSessionsNextDay: [AppointmentSummary]
    var aiGeneratedSummary: String?
    var keyFollowUps: [String]?
    var riskAlerts: [RiskAlert]?
    let generatedAt: Date
    var notifiedAt: Date?
    var userAcknowledgedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case therapistId = "therapist_id"
        case date, reminders
        case completedSessions = "completed_sessions"
        case upcomingSessionsNextDay = "upcoming_sessions_next_day"
        case aiGeneratedSummary = "ai_generated_summary"
        case keyFollowUps = "key_follow_ups"
        case riskAlerts = "risk_alerts"
        case generatedAt = "generated_at"
        case notifiedAt = "notified_at"
        case userAcknowledgedAt = "user_acknowledged_at"
    }

    init(
        id: String = UUID().uuidString,
        therapistId: String = "therapist-1",
        date: Date = Date(),
        reminders: [VoiceReminder] = [],
        completedSessions: [AppointmentSummary] = [],
        upcomingSessionsNextDay: [AppointmentSummary] = [],
        aiGeneratedSummary: String? = nil,
        keyFollowUps: [String]? = nil,
        riskAlerts: [RiskAlert]? = nil,
        generatedAt: Date = Date(),
        notifiedAt: Date? = nil,
        userAcknowledgedAt: Date? = nil
    ) {
        self.id = id
        self.therapistId = therapistId
        self.date = date
        self.reminders = reminders
        self.completedSessions = completedSessions
        self.upcomingSessionsNextDay = upcomingSessionsNextDay
        self.aiGeneratedSummary = aiGeneratedSummary
        self.keyFollowUps = keyFollowUps
        self.riskAlerts = riskAlerts
        self.generatedAt = generatedAt
        self.notifiedAt = notifiedAt
        self.userAcknowledgedAt = userAcknowledgedAt
    }

    // MARK: - Computed Properties

    var totalReminders: Int {
        reminders.count
    }

    var pendingReminders: Int {
        reminders.filter { $0.status.isActionable }.count
    }

    var urgentReminders: [VoiceReminder] {
        reminders.filter { $0.priority == .critical || $0.priority == .high }
    }

    var hasRiskAlerts: Bool {
        !(riskAlerts?.isEmpty ?? true)
    }
}

// MARK: - Appointment Summary (lightweight for daily summary)

struct AppointmentSummary: Codable, Identifiable {
    let id: String
    let clientId: String
    let clientName: String
    let scheduledAt: Date
    let duration: Int
    let sessionType: String?
    let status: String?
    let hasNote: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case clientName = "client_name"
        case scheduledAt = "scheduled_at"
        case duration
        case sessionType = "session_type"
        case status
        case hasNote = "has_note"
    }

    init(from appointment: Appointment) {
        self.id = appointment.id
        self.clientId = appointment.clientId ?? ""
        self.clientName = appointment.client?.name ?? appointment.title
        self.scheduledAt = appointment.scheduledAt
        self.duration = appointment.duration
        self.sessionType = appointment.sessionType?.rawValue
        self.status = appointment.status?.rawValue
        self.hasNote = appointment.progressNoteStatus == "completed"
    }

    init(
        id: String,
        clientId: String,
        clientName: String,
        scheduledAt: Date,
        duration: Int,
        sessionType: String? = nil,
        status: String? = nil,
        hasNote: Bool = false
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.scheduledAt = scheduledAt
        self.duration = duration
        self.sessionType = sessionType
        self.status = status
        self.hasNote = hasNote
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledAt)
    }
}

// MARK: - Risk Alert

struct RiskAlert: Codable, Identifiable {
    let id: String
    let clientId: String
    let clientName: String
    let alertLevel: RiskLevel
    let reason: String
    let sourceReminderId: String?
    let sourceNoteId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case clientName = "client_name"
        case alertLevel = "alert_level"
        case reason
        case sourceReminderId = "source_reminder_id"
        case sourceNoteId = "source_note_id"
    }

    init(
        id: String = UUID().uuidString,
        clientId: String,
        clientName: String,
        alertLevel: RiskLevel,
        reason: String,
        sourceReminderId: String? = nil,
        sourceNoteId: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.alertLevel = alertLevel
        self.reason = reason
        self.sourceReminderId = sourceReminderId
        self.sourceNoteId = sourceNoteId
    }
}
