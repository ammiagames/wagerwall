import Foundation

enum DisableRequestStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case expired
    case cancelled
}

struct DisableRequest: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let requestedAt: Date?
    let cooloffEndsAt: Date
    var partnerApproved: Bool
    var partnerApprovedAt: Date?
    var status: DisableRequestStatus
}

struct DisableRequestInsert: Codable, Sendable {
    let userId: UUID
    let cooloffEndsAt: Date
}
