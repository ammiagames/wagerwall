import Foundation

enum BlockedItemType: String, Codable, CaseIterable, Sendable {
    case app
    case website
}

struct BlockedAttempt: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var blockedItemType: BlockedItemType?
    var blockedCategory: String?
    let attemptedAt: Date?
}

struct BlockedAttemptInsert: Codable, Sendable {
    let userId: UUID
    var blockedItemType: BlockedItemType?
    var blockedCategory: String?
}
