import Foundation

// MARK: - Voice Reminder Model

struct VoiceReminder: Codable, Identifiable, Equatable {
    let id: String
    let therapistId: String
    var clientId: String?
    var sessionId: String?
    var transcription: String
    var audioFileURL: String?
    var isProcessedByAI: Bool
    var aiExtractedFollowUps: [String]?
    var aiSuggestedCategory: ReminderCategory?
    var priority: ReminderPriority
    var status: ReminderStatus
    var scheduledFor: Date?
    var addedToSessionPrep: Bool
    let createdAt: Date
    var processedAt: Date?
    var notifiedAt: Date?

    // Client info for display (not persisted)
    var clientName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case therapistId = "therapist_id"
        case clientId = "client_id"
        case sessionId = "session_id"
        case transcription
        case audioFileURL = "audio_file_url"
        case isProcessedByAI = "is_processed_by_ai"
        case aiExtractedFollowUps = "ai_extracted_follow_ups"
        case aiSuggestedCategory = "ai_suggested_category"
        case priority, status
        case scheduledFor = "scheduled_for"
        case addedToSessionPrep = "added_to_session_prep"
        case createdAt = "created_at"
        case processedAt = "processed_at"
        case notifiedAt = "notified_at"
        case clientName = "client_name"
    }

    init(
        id: String = UUID().uuidString,
        therapistId: String = "therapist-1",
        clientId: String? = nil,
        sessionId: String? = nil,
        transcription: String,
        audioFileURL: String? = nil,
        isProcessedByAI: Bool = false,
        aiExtractedFollowUps: [String]? = nil,
        aiSuggestedCategory: ReminderCategory? = nil,
        priority: ReminderPriority = .medium,
        status: ReminderStatus = .recorded,
        scheduledFor: Date? = nil,
        addedToSessionPrep: Bool = false,
        createdAt: Date = Date(),
        processedAt: Date? = nil,
        notifiedAt: Date? = nil,
        clientName: String? = nil
    ) {
        self.id = id
        self.therapistId = therapistId
        self.clientId = clientId
        self.sessionId = sessionId
        self.transcription = transcription
        self.audioFileURL = audioFileURL
        self.isProcessedByAI = isProcessedByAI
        self.aiExtractedFollowUps = aiExtractedFollowUps
        self.aiSuggestedCategory = aiSuggestedCategory
        self.priority = priority
        self.status = status
        self.scheduledFor = scheduledFor
        self.addedToSessionPrep = addedToSessionPrep
        self.createdAt = createdAt
        self.processedAt = processedAt
        self.notifiedAt = notifiedAt
        self.clientName = clientName
    }

    static func == (lhs: VoiceReminder, rhs: VoiceReminder) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Reminder Category

enum ReminderCategory: String, Codable, CaseIterable {
    case sessionFollowUp = "session_follow_up"
    case clinicalNote = "clinical_note"
    case homework
    case riskFlag = "risk_flag"
    case administrative
    case personal
    case urgent

    var displayName: String {
        switch self {
        case .sessionFollowUp: return "Session Follow-Up"
        case .clinicalNote: return "Clinical Note"
        case .homework: return "Homework"
        case .riskFlag: return "Risk Flag"
        case .administrative: return "Administrative"
        case .personal: return "Personal"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .sessionFollowUp: return "arrow.right.circle"
        case .clinicalNote: return "note.text"
        case .homework: return "book"
        case .riskFlag: return "exclamationmark.triangle"
        case .administrative: return "folder"
        case .personal: return "person"
        case .urgent: return "bolt.fill"
        }
    }

    var color: String {
        switch self {
        case .sessionFollowUp: return "blue"
        case .clinicalNote: return "purple"
        case .homework: return "green"
        case .riskFlag: return "red"
        case .administrative: return "gray"
        case .personal: return "orange"
        case .urgent: return "red"
        }
    }
}

// MARK: - Reminder Priority

enum ReminderPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Reminder Status

enum ReminderStatus: String, Codable {
    case recorded
    case transcribed
    case processing
    case ready
    case notified
    case dismissed
    case completed
    case addedToPrep = "added_to_prep"

    var displayName: String {
        switch self {
        case .recorded: return "Recorded"
        case .transcribed: return "Transcribed"
        case .processing: return "Processing"
        case .ready: return "Ready"
        case .notified: return "Notified"
        case .dismissed: return "Dismissed"
        case .completed: return "Completed"
        case .addedToPrep: return "Added to Prep"
        }
    }

    var isActionable: Bool {
        switch self {
        case .ready, .notified:
            return true
        default:
            return false
        }
    }
}

// MARK: - Voice Reminder Input (for API)

struct VoiceReminderInput: Codable {
    let clientId: String?
    let sessionId: String?
    let transcription: String
    let audioFileURL: String?
    let priority: ReminderPriority?
    let scheduledFor: Date?

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case sessionId = "session_id"
        case transcription
        case audioFileURL = "audio_file_url"
        case priority
        case scheduledFor = "scheduled_for"
    }
}

// MARK: - Processed Reminder (AI Result)

struct ProcessedReminder: Codable {
    let extractedFollowUps: [String]
    let suggestedCategory: ReminderCategory
    let suggestedPriority: ReminderPriority
    let keyEntities: [String]
    let actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case extractedFollowUps = "extracted_follow_ups"
        case suggestedCategory = "suggested_category"
        case suggestedPriority = "suggested_priority"
        case keyEntities = "key_entities"
        case actionItems = "action_items"
    }
}

// MARK: - Voice Reminder Summary (for Session Prep)

struct VoiceReminderSummary: Codable {
    let reminderId: String
    let transcription: String
    let aiSummary: String?
    let priority: ReminderPriority
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case reminderId = "reminder_id"
        case transcription
        case aiSummary = "ai_summary"
        case priority
        case createdAt = "created_at"
    }
}
