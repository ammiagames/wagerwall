import Foundation
import Supabase

@Observable
final class UrgeLogViewModel {
    var intensity: Double = 5
    var triggerCategory: String = ""
    var triggerNotes: String = ""
    var copingStrategy: String = ""
    var outcome: UrgeOutcome = .resisted
    var isSaving = false
    var error: String?

    static let triggerCategories = [
        "Emotional",
        "Environmental",
        "Social",
        "Financial",
        "Boredom",
        "Stress",
        "Celebration"
    ]

    func save(userId: UUID, repo: any UrgeLogRepository) async -> UrgeLog? {
        isSaving = true
        error = nil

        let insert = UrgeLogInsert(
            userId: userId,
            intensity: Int(intensity),
            triggerCategory: triggerCategory.isEmpty ? nil : triggerCategory.lowercased(),
            triggerNotes: triggerNotes.isEmpty ? nil : triggerNotes,
            copingStrategyUsed: copingStrategy.isEmpty ? nil : copingStrategy,
            outcome: outcome
        )

        do {
            let log = try await repo.createLog(insert: insert)
            isSaving = false
            return log
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
