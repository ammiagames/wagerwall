import Foundation

enum UrgeOutcome: String, Codable, CaseIterable, Sendable {
    case resisted
    case gaveIn = "gave_in"
    case usedPanicButton = "used_panic_button"
}

struct UrgeLog: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var intensity: Int
    var triggerCategory: String?
    var triggerNotes: String?
    var copingStrategyUsed: String?
    var outcome: UrgeOutcome?
    let loggedAt: Date?
}

struct UrgeLogInsert: Codable, Sendable {
    let userId: UUID
    let intensity: Int
    var triggerCategory: String?
    var triggerNotes: String?
    var copingStrategyUsed: String?
    var outcome: UrgeOutcome?
}
