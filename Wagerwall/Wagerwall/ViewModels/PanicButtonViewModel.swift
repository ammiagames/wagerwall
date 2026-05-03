import Foundation
import Supabase

@Observable
final class PanicButtonViewModel {
    enum PanicStep: CaseIterable {
        case breathing
        case motivation
        case outcome
    }

    var currentStep: PanicStep = .breathing
    var outcome: UrgeOutcome = .resisted
    var isSaving = false
    var isComplete = false
    var error: String?

    static let motivationalQuotes: [(text: String, author: String)] = [
        ("Recovery is not a race. You don't have to feel guilty if it takes you longer than you thought.", "Unknown"),
        ("The only person you are destined to become is the person you decide to be.", "Ralph Waldo Emerson"),
        ("You are stronger than you think. More capable than you ever imagined.", "Unknown"),
        ("Every day is a new opportunity to change your life. Every day is a new opportunity to make new choices.", "Unknown"),
        ("It does not matter how slowly you go, as long as you do not stop.", "Confucius"),
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("Fall seven times, stand up eight.", "Japanese Proverb"),
        ("Courage isn't having the strength to go on — it is going on when you don't have the strength.", "Napoleon Bonaparte"),
        ("You don't have to control your thoughts. You just have to stop letting them control you.", "Dan Millman"),
        ("One day at a time. One hour at a time. One minute at a time. You can do this.", "Unknown"),
    ]

    func advance() {
        switch currentStep {
        case .breathing: currentStep = .motivation
        case .motivation: currentStep = .outcome
        case .outcome: break
        }
    }

    func logAndComplete(userId: UUID, urgeRepo: any UrgeLogRepository) async {
        isSaving = true
        error = nil

        let insert = UrgeLogInsert(
            userId: userId,
            intensity: 8,
            triggerCategory: nil,
            triggerNotes: "Panic button activated",
            copingStrategyUsed: "Breathing exercise + motivational cards",
            outcome: outcome
        )

        do {
            _ = try await urgeRepo.createLog(insert: insert)
            isComplete = true
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}
