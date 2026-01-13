import Foundation

enum AppointmentCategory: String, Codable, CaseIterable {
    case work
    case personal
    case meeting
    case other

    var color: String {
        switch self {
        case .work: return "blue"
        case .personal: return "green"
        case .meeting: return "purple"
        case .other: return "gray"
        }
    }
}

enum SessionType: String, Codable, CaseIterable {
    case individual
    case couples
    case family
    case group
}

enum AppointmentStatus: String, Codable, CaseIterable {
    case scheduled
    case completed
    case cancelled
    case noShow = "no-show"
}

// Appointment/Session model - compatible with TherapyFlow sessions
struct Appointment: Codable, Identifiable, Equatable {
    let id: String  // UUID
    var clientId: String?
    let therapistId: String?
    var scheduledAt: Date
    var duration: Int  // minutes
    var sessionType: SessionType?
    var status: AppointmentStatus?
    var googleEventId: String?
    var notes: String?
    var hasProgressNotePlaceholder: Bool?
    var progressNoteStatus: String?
    var isSimplePracticeEvent: Bool?
    var client: Client?
    let createdAt: Date
    var updatedAt: Date?

    // Computed properties for UI compatibility
    var title: String {
        if let client = client {
            return "\(client.name) - \(sessionType?.rawValue.capitalized ?? "Session")"
        }
        return sessionType?.rawValue.capitalized ?? "Session"
    }

    var clientName: String? {
        client?.name
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var date: String {
        Self.dateFormatter.string(from: scheduledAt)
    }

    var startTime: Date {
        scheduledAt
    }

    var endTime: Date {
        scheduledAt.addingTimeInterval(Double(duration) * 60)
    }

    var startTimeFormatted: String {
        Self.timeFormatter.string(from: scheduledAt)
    }

    var endTimeFormatted: String {
        Self.timeFormatter.string(from: endTime)
    }

    var durationFormatted: String {
        let hours = duration / 60
        let minutes = duration % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var category: AppointmentCategory? {
        switch sessionType {
        case .individual, .couples, .family: return .work
        case .group: return .meeting
        case .none: return .other
        }
    }

    var sessionNumber: Int? {
        nil // Could be computed from session history
    }

    // CodingKeys for TherapyFlow API compatibility
    enum CodingKeys: String, CodingKey {
        case id
        case clientId
        case therapistId
        case scheduledAt
        case duration
        case sessionType
        case status
        case googleEventId
        case notes
        case hasProgressNotePlaceholder
        case progressNoteStatus
        case isSimplePracticeEvent
        case client
        case createdAt
        case updatedAt
    }
}

struct AppointmentInput: Codable {
    var clientId: String
    var scheduledAt: Date
    var duration: Int = 50
    var sessionType: SessionType
    var status: AppointmentStatus?
    var notes: String?
    var googleEventId: String?
}
