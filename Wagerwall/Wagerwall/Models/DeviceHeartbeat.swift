import Foundation

struct DeviceHeartbeat: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var deviceId: String
    var apnsToken: String?
    var lastHeartbeat: Date?
    var isActive: Bool
}

struct DeviceHeartbeatUpsert: Codable, Sendable {
    let userId: UUID
    let deviceId: String
    var apnsToken: String?
    var lastHeartbeat: Date?
    var isActive: Bool?
}
