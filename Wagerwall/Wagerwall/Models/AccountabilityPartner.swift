import Foundation

enum PartnerStatus: String, Codable, CaseIterable, Sendable {
    case invited
    case active
    case removed
}

struct AccountabilityPartner: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var partnerUserId: UUID?
    var partnerEmail: String?
    var partnerPhone: String?
    var lockCodeHash: String?
    var status: PartnerStatus
    let invitedAt: Date?
    var activatedAt: Date?
}

struct AccountabilityPartnerInsert: Codable, Sendable {
    let userId: UUID
    var partnerEmail: String?
    var partnerPhone: String?
}
