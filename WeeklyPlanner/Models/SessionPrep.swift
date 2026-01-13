import Foundation

// MARK: - API Response Wrapper

struct SessionPrepResponse: Codable {
    let success: Bool
    let prep: SessionPrepContent
    let prepId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case prep
        case prepId
    }
}

// MARK: - Session Prep (for UI)

struct SessionPrep: Codable, Identifiable {
    let id: String
    let sessionId: String
    let clientId: String
    let therapistId: String
    var prep: SessionPrepContent
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case clientId = "client_id"
        case therapistId = "therapist_id"
        case prep
        case createdAt = "created_at"
    }

    // Create from API response
    init(from response: SessionPrepResponse, sessionId: String, clientId: String) {
        self.id = response.prepId ?? UUID().uuidString
        self.sessionId = sessionId
        self.clientId = clientId
        self.therapistId = "therapist-1"
        self.prep = response.prep
        self.createdAt = Date()
    }

    init(id: String, sessionId: String, clientId: String, therapistId: String, prep: SessionPrepContent, createdAt: Date) {
        self.id = id
        self.sessionId = sessionId
        self.clientId = clientId
        self.therapistId = therapistId
        self.prep = prep
        self.createdAt = createdAt
    }
}

// MARK: - Session Prep Content (matches API response)

struct SessionPrepContent: Codable {
    // Direct API fields
    var clientName: String?
    var prepGenerated: String?
    var upcomingSession: String?
    var whereWeLeftOff: WhereWeLeftOff?
    var homeworkFollowUp: HomeworkFollowUp?
    var treatmentPlanStatus: TreatmentPlanStatus?
    var clinicalFlags: ClinicalFlags?
    var patternAnalysis: PatternAnalysis?
    var suggestedOpeners: SuggestedOpeners?
    var sessionFocusSuggestions: [String]?
    var clinicianReminders: [String]?

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case prepGenerated = "prep_generated"
        case upcomingSession = "upcoming_session"
        case whereWeLeftOff = "where_we_left_off"
        case homeworkFollowUp = "homework_follow_up"
        case treatmentPlanStatus = "treatment_plan_status"
        case clinicalFlags = "clinical_flags"
        case patternAnalysis = "pattern_analysis"
        case suggestedOpeners = "suggested_openers"
        case sessionFocusSuggestions = "session_focus_suggestions"
        case clinicianReminders = "clinician_reminders"
    }

    // MARK: - Computed properties for UI compatibility

    var sessionFocus: String? {
        sessionFocusSuggestions?.first
    }

    var lastSessionSummary: String? {
        if let tone = whereWeLeftOff?.emotionalTone {
            return tone
        }
        if let note = whereWeLeftOff?.sessionEndingNote {
            return note
        }
        return nil
    }

    var keyThemes: [String]? {
        whereWeLeftOff?.keyThemes ?? patternAnalysis?.recurringThemes
    }

    var treatmentGoals: [String]? {
        treatmentPlanStatus?.goalsNeedingAttention
    }

    var suggestedTopics: [String]? {
        sessionFocusSuggestions
    }

    var significantQuotes: [String]? {
        // Use openers as quotes since API doesn't have actual quotes
        suggestedOpeners?.contentOpeners
    }

    var riskAlerts: [String]? {
        guard let flags = clinicalFlags else { return nil }
        var alerts: [String] = []
        if let level = flags.riskLevel, level != "low" && level != "none" {
            alerts.append("Risk level: \(level.capitalized)")
        }
        if let factors = flags.riskFactors {
            alerts.append(contentsOf: factors)
        }
        return alerts.isEmpty ? nil : alerts
    }

    var clientStrengths: [String]? {
        treatmentPlanStatus?.progressIndicators
    }

    var followUpItems: [String]? {
        homeworkFollowUp?.followUpQuestions ?? clinicianReminders
    }

    var sessionNumber: Int? {
        nil // Not provided by API
    }
}

// MARK: - Nested Types

struct WhereWeLeftOff: Codable {
    var keyThemes: [String]?
    var emotionalTone: String?
    var unresolvedThreads: [String]?
    var sessionEndingNote: String?

    enum CodingKeys: String, CodingKey {
        case keyThemes = "key_themes"
        case emotionalTone = "emotional_tone"
        case unresolvedThreads = "unresolved_threads"
        case sessionEndingNote = "session_ending_note"
    }
}

struct HomeworkFollowUp: Codable {
    var assignments: [String]?
    var followUpQuestions: [String]?
    var daysSinceAssignment: Int?

    enum CodingKeys: String, CodingKey {
        case assignments
        case followUpQuestions = "follow_up_questions"
        case daysSinceAssignment = "days_since_assignment"
    }
}

struct TreatmentPlanStatus: Codable {
    var goalsAddressedRecently: [String]?
    var goalsNeedingAttention: [String]?
    var progressIndicators: [String]?
    var setbackIndicators: [String]?

    enum CodingKeys: String, CodingKey {
        case goalsAddressedRecently = "goals_addressed_recently"
        case goalsNeedingAttention = "goals_needing_attention"
        case progressIndicators = "progress_indicators"
        case setbackIndicators = "setback_indicators"
    }
}

struct ClinicalFlags: Codable {
    var riskLevel: String?
    var riskFactors: [String]?
    var somaticComplaints: [String]?
    var sleepAppetiteChanges: String?
    var requiresAssessment: [String]?

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case riskFactors = "risk_factors"
        case somaticComplaints = "somatic_complaints"
        case sleepAppetiteChanges = "sleep_appetite_changes"
        case requiresAssessment = "requires_assessment"
    }
}

struct PatternAnalysis: Codable {
    var recurringThemes: [String]?
    var emotionalTrajectory: String?
    var therapeuticAllianceNotes: String?
    var modalityEffectiveness: [String: String]?

    enum CodingKeys: String, CodingKey {
        case recurringThemes = "recurring_themes"
        case emotionalTrajectory = "emotional_trajectory"
        case therapeuticAllianceNotes = "therapeutic_alliance_notes"
        case modalityEffectiveness = "modality_effectiveness"
    }
}

struct SuggestedOpeners: Codable {
    var warmOpeners: [String]?
    var contentOpeners: [String]?
    var homeworkOpeners: [String]?

    enum CodingKeys: String, CodingKey {
        case warmOpeners = "warm_openers"
        case contentOpeners = "content_openers"
        case homeworkOpeners = "homework_openers"
    }
}

// MARK: - Prep Status

enum PrepStatus: String, Codable {
    case pending
    case generating
    case ready
    case failed
}
