import Foundation

// Progress Note from TherapyFlow
struct SessionNote: Codable, Identifiable, Equatable {
    let id: String  // UUID
    let clientId: String
    let sessionId: String?
    let therapistId: String
    var content: String?
    var sessionDate: Date
    var tags: [String]?
    var aiTags: [String]?
    var riskLevel: RiskLevel?
    var progressRating: Int?
    var qualityScore: Double?
    var qualityFlags: [String: Bool]?
    var status: NoteStatus?
    var isPlaceholder: Bool?
    var requiresManualReview: Bool?
    var aiConfidenceScore: Double?
    var processingNotes: String?
    var client: Client?
    let createdAt: Date
    var updatedAt: Date?
}

enum RiskLevel: String, Codable, CaseIterable {
    case low
    case moderate
    case high
    case critical

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum NoteStatus: String, Codable {
    case placeholder
    case uploaded
    case processed
    case manualReview = "manual_review"
    case completed
}

struct SessionNoteInput: Codable {
    var clientId: String
    var sessionId: String?
    var content: String
    var sessionDate: Date
    var tags: [String]?
    var riskLevel: RiskLevel?
    var progressRating: Int?
}

// Legacy SessionMood for UI compatibility
enum SessionMood: String, Codable, CaseIterable {
    case veryLow = "very_low"
    case low = "low"
    case neutral = "neutral"
    case good = "good"
    case veryGood = "very_good"

    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .veryGood: return "Very Good"
        }
    }

    var emoji: String {
        switch self {
        case .veryLow: return "😢"
        case .low: return "😔"
        case .neutral: return "😐"
        case .good: return "🙂"
        case .veryGood: return "😊"
        }
    }
}
