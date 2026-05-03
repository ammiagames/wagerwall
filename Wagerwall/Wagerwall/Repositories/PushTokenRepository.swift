import Foundation
import Supabase

protocol PushTokenRepository: Sendable {
    func registerToken(insert: PushTokenInsert) async throws -> PushToken
    func removeToken(userId: UUID, token: String) async throws
}

struct SupabasePushTokenRepository: PushTokenRepository {
    func registerToken(insert: PushTokenInsert) async throws -> PushToken {
        try await supabase.from("push_tokens")
            .upsert(insert, onConflict: "user_id,token")
            .select()
            .single()
            .execute()
            .value
    }

    func removeToken(userId: UUID, token: String) async throws {
        try await supabase.from("push_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("token", value: token)
            .execute()
    }
}
