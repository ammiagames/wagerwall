import Foundation

struct PushToken: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let token: String
    var platform: String?
    let createdAt: Date?
}

struct PushTokenInsert: Codable, Sendable {
    let userId: UUID
    let token: String
    var platform: String? = "ios"
}
