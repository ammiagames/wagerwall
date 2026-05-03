import Foundation
import Supabase

protocol MoodLogRepository: Sendable {
    func fetchLogs(userId: UUID, limit: Int) async throws -> [MoodLog]
    func fetchTodaysLog(userId: UUID) async throws -> MoodLog?
    func createLog(insert: MoodLogInsert) async throws -> MoodLog
}

struct SupabaseMoodLogRepository: MoodLogRepository {
    func fetchLogs(userId: UUID, limit: Int = 30) async throws -> [MoodLog] {
        try await supabase.from("mood_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchTodaysLog(userId: UUID) async throws -> MoodLog? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let results: [MoodLog] = try await supabase.from("mood_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("logged_at", value: startOfDay.ISO8601Format())
            .order("logged_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func createLog(insert: MoodLogInsert) async throws -> MoodLog {
        try await supabase.from("mood_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }
}
