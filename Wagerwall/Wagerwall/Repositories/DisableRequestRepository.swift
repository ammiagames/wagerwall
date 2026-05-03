import Foundation
import Supabase

protocol DisableRequestRepository: Sendable {
    func fetchActiveRequest(userId: UUID) async throws -> DisableRequest?
    func createRequest(insert: DisableRequestInsert) async throws -> DisableRequest
    func cancelRequest(requestId: UUID) async throws
}

struct SupabaseDisableRequestRepository: DisableRequestRepository {
    func fetchActiveRequest(userId: UUID) async throws -> DisableRequest? {
        let results: [DisableRequest] = try await supabase.from("disable_requests")
            .select()
            .eq("user_id", value: userId)
            .in("status", values: ["pending", "approved"])
            .order("requested_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func createRequest(insert: DisableRequestInsert) async throws -> DisableRequest {
        try await supabase.from("disable_requests")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func cancelRequest(requestId: UUID) async throws {
        try await supabase.from("disable_requests")
            .update(["status": "cancelled"])
            .eq("id", value: requestId)
            .execute()
    }
}
