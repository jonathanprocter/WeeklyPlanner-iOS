import Foundation

struct User: Codable, Identifiable {
    let id: Int
    var email: String
    var name: String?
    var profilePicture: String?
    var googleId: String?
    let createdAt: Date
    var updatedAt: Date?
}

struct UserResponse: Codable {
    let result: UserResultData
}

struct UserResultData: Codable {
    let data: UserData
}

struct UserData: Codable {
    let json: User?
}
