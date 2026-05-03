import Foundation
import Supabase

@Observable
final class MoodLogViewModel {
    var moodScore: Int = 3
    var notes: String = ""
    var isSaving = false
    var error: String?

    static let moodFaces: [(score: Int, emoji: String, label: String)] = [
        (1, "😢", "Awful"),
        (2, "😟", "Bad"),
        (3, "😐", "Okay"),
        (4, "🙂", "Good"),
        (5, "😄", "Great")
    ]

    func save(userId: UUID, repo: any MoodLogRepository) async -> MoodLog? {
        isSaving = true
        error = nil

        let insert = MoodLogInsert(
            userId: userId,
            moodScore: moodScore,
            notes: notes.isEmpty ? nil : notes
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
