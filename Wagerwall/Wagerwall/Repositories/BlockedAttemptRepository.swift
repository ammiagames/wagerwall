import Foundation
import Supabase

protocol BlockedAttemptRepository: Sendable {
    func fetchAttempts(userId: UUID, limit: Int) async throws -> [BlockedAttempt]
    func fetchCount(userId: UUID) async throws -> Int
    func logAttempt(insert: BlockedAttemptInsert) async throws -> BlockedAttempt
}

struct SupabaseBlockedAttemptRepository: BlockedAttemptRepository {
    func fetchAttempts(userId: UUID, limit: Int = 50) async throws -> [BlockedAttempt] {
        try await supabase.from("blocked_attempts")
            .select()
            .eq("user_id", value: userId)
            .order("attempted_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchCount(userId: UUID) async throws -> Int {
        let response = try await supabase.from("blocked_attempts")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        return response.count ?? 0
    }

    func logAttempt(insert: BlockedAttemptInsert) async throws -> BlockedAttempt {
        try await supabase.from("blocked_attempts")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }
}
