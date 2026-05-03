import Foundation

struct MoodLog: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var moodScore: Int
    var notes: String?
    let loggedAt: Date?
}

struct MoodLogInsert: Codable, Sendable {
    let userId: UUID
    let moodScore: Int
    var notes: String?
}
