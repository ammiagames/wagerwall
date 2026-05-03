import Foundation
import Supabase

protocol UserProfileRepository: Sendable {
    func fetchProfile(userId: UUID) async throws -> UserProfile
    func updateProfile(userId: UUID, update: UserProfileUpdate) async throws -> UserProfile
    func deleteAccount(userId: UUID) async throws
}

struct SupabaseUserProfileRepository: UserProfileRepository {
    func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await supabase.from("user_profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func updateProfile(userId: UUID, update: UserProfileUpdate) async throws -> UserProfile {
        try await supabase.from("user_profiles")
            .update(update)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteAccount(userId: UUID) async throws {
        try await supabase.from("user_profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
    }
}
