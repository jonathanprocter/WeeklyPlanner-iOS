import Foundation

struct Client: Codable, Identifiable, Equatable, Hashable {
    let id: String  // UUID
    let therapistId: String
    var name: String
    var email: String?
    var phone: String?
    var dateOfBirth: Date?
    var emergencyContact: EmergencyContact?
    var insurance: Insurance?
    var tags: [String]?
    var clinicalConsiderations: [String]?
    var preferredModalities: [String]?
    var status: ClientStatus?
    var deletedAt: Date?
    let createdAt: Date
    var updatedAt: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct EmergencyContact: Codable, Equatable {
    var name: String?
    var phone: String?
    var relationship: String?
}

struct Insurance: Codable, Equatable {
    var provider: String?
    var policyNumber: String?
    var groupNumber: String?
}

enum ClientStatus: String, Codable, CaseIterable {
    case active
    case inactive
    case discharged
}

struct ClientInput: Codable {
    var name: String
    var email: String?
    var phone: String?
    var dateOfBirth: Date?
    var emergencyContact: EmergencyContact?
    var insurance: Insurance?
    var tags: [String]?
    var clinicalConsiderations: [String]?
    var preferredModalities: [String]?
    var status: ClientStatus?
}
