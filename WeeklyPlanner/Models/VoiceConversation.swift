import Foundation

// MARK: - Voice Conversation

struct VoiceConversation: Codable, Identifiable {
    let id: String
    let therapistId: String
    var messages: [ConversationMessage]
    var context: ConversationContext?
    let startedAt: Date
    var endedAt: Date?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case therapistId = "therapist_id"
        case messages, context
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case isActive = "is_active"
    }

    init(
        id: String = UUID().uuidString,
        therapistId: String = "therapist-1",
        messages: [ConversationMessage] = [],
        context: ConversationContext? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.therapistId = therapistId
        self.messages = messages
        self.context = context
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isActive = isActive
    }

    mutating func addMessage(_ message: ConversationMessage) {
        messages.append(message)
    }

    mutating func end() {
        endedAt = Date()
        isActive = false
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Codable, Identifiable {
    let id: String
    let role: MessageRole
    var content: String
    var audioURL: String?
    var intent: DetectedIntent?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case audioURL = "audio_url"
        case intent, timestamp
    }

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        audioURL: String? = nil,
        intent: DetectedIntent? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.audioURL = audioURL
        self.intent = intent
        self.timestamp = timestamp
    }
}

// MARK: - Message Role

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Detected Intent

struct DetectedIntent: Codable {
    var action: IntentAction
    var entityType: String?
    var entityId: String?
    var entityName: String?
    var timeReference: TimeReference?
    var parameters: [String: String]?

    enum CodingKeys: String, CodingKey {
        case action
        case entityType = "entity_type"
        case entityId = "entity_id"
        case entityName = "entity_name"
        case timeReference = "time_reference"
        case parameters
    }
}

// MARK: - Intent Action

enum IntentAction: String, Codable {
    case queryNextAppointment = "query_next_appointment"
    case queryClientHistory = "query_client_history"
    case queryPreviousSession = "query_previous_session"
    case querySessionPrep = "query_session_prep"
    case createReminder = "create_reminder"
    case searchClients = "search_clients"
    case getSchedule = "get_schedule"
    case getDailySummary = "get_daily_summary"
    case getClientInfo = "get_client_info"
    case unknown

    var requiresEntity: Bool {
        switch self {
        case .queryClientHistory, .queryPreviousSession, .querySessionPrep, .getClientInfo:
            return true
        default:
            return false
        }
    }
}

// MARK: - Time Reference

struct TimeReference: Codable {
    var type: TimeReferenceType
    var date: Date?
    var startDate: Date?
    var endDate: Date?

    enum CodingKeys: String, CodingKey {
        case type, date
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

enum TimeReferenceType: String, Codable {
    case today
    case tomorrow
    case thisWeek = "this_week"
    case nextWeek = "next_week"
    case specific
    case range
    case relative
    case lastSession = "last_session"
}

// MARK: - Conversation Context

struct ConversationContext: Codable {
    var currentClientId: String?
    var currentClientName: String?
    var currentAppointmentId: String?
    var recentQueryResults: [String]?
    var lastIntent: IntentAction?

    enum CodingKeys: String, CodingKey {
        case currentClientId = "current_client_id"
        case currentClientName = "current_client_name"
        case currentAppointmentId = "current_appointment_id"
        case recentQueryResults = "recent_query_results"
        case lastIntent = "last_intent"
    }

    init(
        currentClientId: String? = nil,
        currentClientName: String? = nil,
        currentAppointmentId: String? = nil,
        recentQueryResults: [String]? = nil,
        lastIntent: IntentAction? = nil
    ) {
        self.currentClientId = currentClientId
        self.currentClientName = currentClientName
        self.currentAppointmentId = currentAppointmentId
        self.recentQueryResults = recentQueryResults
        self.lastIntent = lastIntent
    }

    mutating func setClient(id: String?, name: String?) {
        currentClientId = id
        currentClientName = name
    }

    mutating func clear() {
        currentClientId = nil
        currentClientName = nil
        currentAppointmentId = nil
        recentQueryResults = nil
        lastIntent = nil
    }
}
