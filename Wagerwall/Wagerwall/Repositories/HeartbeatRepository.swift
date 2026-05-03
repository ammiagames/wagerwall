import Foundation
import Supabase

protocol HeartbeatRepository: Sendable {
    func fetchHeartbeat(userId: UUID, deviceId: String) async throws -> DeviceHeartbeat?
    func upsertHeartbeat(upsert: DeviceHeartbeatUpsert) async throws -> DeviceHeartbeat
    func sendHeartbeat(userId: UUID, deviceId: String) async throws -> DeviceHeartbeat
}

struct SupabaseHeartbeatRepository: HeartbeatRepository {
    func fetchHeartbeat(userId: UUID, deviceId: String) async throws -> DeviceHeartbeat? {
        let results: [DeviceHeartbeat] = try await supabase.from("device_heartbeats")
            .select()
            .eq("user_id", value: userId)
            .eq("device_id", value: deviceId)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func upsertHeartbeat(upsert: DeviceHeartbeatUpsert) async throws -> DeviceHeartbeat {
        try await supabase.from("device_heartbeats")
            .upsert(upsert, onConflict: "user_id,device_id")
            .select()
            .single()
            .execute()
            .value
    }

    func sendHeartbeat(userId: UUID, deviceId: String) async throws -> DeviceHeartbeat {
        let upsert = DeviceHeartbeatUpsert(
            userId: userId,
            deviceId: deviceId,
            lastHeartbeat: Date(),
            isActive: true
        )
        return try await upsertHeartbeat(upsert: upsert)
    }
}
