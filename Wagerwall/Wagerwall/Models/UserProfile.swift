import Foundation

enum GamblingSeverity: String, Codable, CaseIterable, Sendable {
    case low
    case moderate
    case high
    case severe
}

struct UserProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String?
    var avatarUrl: String?
    var gamblingSeverity: GamblingSeverity?
    var assessmentScore: Int?
    var quitDate: Date?
    var dailyGamblingSpend: Double?
    var timezone: String?
    var onboardingCompleted: Bool?
    let createdAt: Date?
    var updatedAt: Date?
}

struct UserProfileUpdate: Codable, Sendable {
    var displayName: String?
    var avatarUrl: String?
    var gamblingSeverity: GamblingSeverity?
    var assessmentScore: Int?
    var quitDate: Date?
    var dailyGamblingSpend: Double?
    var timezone: String?
    var onboardingCompleted: Bool?
}
