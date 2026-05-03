import Foundation

struct UserStreak: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var currentStreakDays: Int
    var longestStreakDays: Int
    var lastCheckIn: String? // DATE type comes as "YYYY-MM-DD" string
    var moneySavedEstimate: Double
}
