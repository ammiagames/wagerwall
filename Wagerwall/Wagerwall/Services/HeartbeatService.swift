import Foundation
import BackgroundTasks
import UIKit
import Supabase

@Observable
final class HeartbeatService {
    static let taskIdentifier = "com.wagerwall.app.heartbeat"

    private let heartbeatRepo: any HeartbeatRepository
    private var timer: Timer?

    var lastHeartbeat: Date?
    var isActive = false

    init(heartbeatRepo: any HeartbeatRepository = SupabaseHeartbeatRepository()) {
        self.heartbeatRepo = heartbeatRepo
    }

    // MARK: - Device ID

    private var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: "wagerwall_device_id") {
            return existing
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "wagerwall_device_id")
        return id
    }

    // MARK: - Foreground Heartbeat

    func startForegroundHeartbeat(userId: UUID) {
        isActive = true
        // Send initial heartbeat
        Task { await sendHeartbeat(userId: userId) }

        // Repeat every 5 minutes
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.sendHeartbeat(userId: userId) }
        }
    }

    func stopForegroundHeartbeat() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    func sendHeartbeat(userId: UUID) async {
        do {
            let result = try await heartbeatRepo.sendHeartbeat(userId: userId, deviceId: deviceId)
            lastHeartbeat = result.lastHeartbeat
        } catch {
            // Silently handle — heartbeat is best-effort
        }
    }

    // MARK: - Background Task Registration

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(refreshTask)
        }
    }

    static func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 300) // 5 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling failed — non-critical
        }
    }

    private static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleBackgroundTask()

        let service = HeartbeatService()

        task.expirationHandler = {
            // Clean up if needed
        }

        Task {
            guard let session = try? await supabase.auth.session else {
                task.setTaskCompleted(success: true)
                return
            }
            await service.sendHeartbeat(userId: session.user.id)
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Update APNs Token

    func updateAPNsToken(userId: UUID, token: String) async {
        let upsert = DeviceHeartbeatUpsert(
            userId: userId,
            deviceId: deviceId,
            apnsToken: token,
            lastHeartbeat: Date(),
            isActive: true
        )
        do {
            _ = try await heartbeatRepo.upsertHeartbeat(upsert: upsert)
        } catch {
            // Best-effort
        }
    }
}
