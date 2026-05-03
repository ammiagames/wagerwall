import Foundation
import Supabase

protocol StreakRepository: Sendable {
    func fetchStreak(userId: UUID) async throws -> UserStreak
    func checkIn(userId: UUID) async throws -> UserStreak
}

struct SupabaseStreakRepository: StreakRepository {
    func fetchStreak(userId: UUID) async throws -> UserStreak {
        try await supabase.from("user_streaks")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
    }

    func checkIn(userId: UUID) async throws -> UserStreak {
        let today = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withFullDate]
        )
        // Server-side streak logic runs via cron; client just records check-in date
        return try await supabase.from("user_streaks")
            .update(["last_check_in": today])
            .eq("user_id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }
}
