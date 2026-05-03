import Foundation
import Supabase

protocol UrgeLogRepository: Sendable {
    func fetchLogs(userId: UUID, limit: Int) async throws -> [UrgeLog]
    func createLog(insert: UrgeLogInsert) async throws -> UrgeLog
}

struct SupabaseUrgeLogRepository: UrgeLogRepository {
    func fetchLogs(userId: UUID, limit: Int = 50) async throws -> [UrgeLog] {
        try await supabase.from("urge_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func createLog(insert: UrgeLogInsert) async throws -> UrgeLog {
        try await supabase.from("urge_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }
}
