import Foundation
import Supabase

protocol AccountabilityPartnerRepository: Sendable {
    func fetchPartners(userId: UUID) async throws -> [AccountabilityPartner]
    func invitePartner(insert: AccountabilityPartnerInsert) async throws -> AccountabilityPartner
    func removePartner(partnerId: UUID) async throws
}

struct SupabaseAccountabilityPartnerRepository: AccountabilityPartnerRepository {
    func fetchPartners(userId: UUID) async throws -> [AccountabilityPartner] {
        try await supabase.from("accountability_partners")
            .select()
            .eq("user_id", value: userId)
            .order("invited_at", ascending: false)
            .execute()
            .value
    }

    func invitePartner(insert: AccountabilityPartnerInsert) async throws -> AccountabilityPartner {
        try await supabase.from("accountability_partners")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func removePartner(partnerId: UUID) async throws {
        try await supabase.from("accountability_partners")
            .update(["status": "removed"])
            .eq("id", value: partnerId)
            .execute()
    }
}
