import Foundation

struct DailyNote: Codable, Identifiable {
    let id: Int
    let userId: Int
    var date: String // YYYY-MM-DD format
    var content: String?
    var goals: String?
    var reflections: String?
    var mood: Int?
    var energy: Int?
    let createdAt: Date
    var updatedAt: Date?
}

struct DailyNoteInput: Codable {
    var date: String
    var content: String?
    var goals: String?
    var reflections: String?
    var mood: Int?
    var energy: Int?
}

struct DailyNoteResponse: Codable {
    let result: DailyNoteResultData
}

struct DailyNoteResultData: Codable {
    let data: DailyNoteData
}

struct DailyNoteData: Codable {
    let json: DailyNote?
}
