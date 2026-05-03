import Foundation
import UserNotifications
import UIKit
import Supabase

@Observable
final class NotificationService: NSObject {
    var isAuthorized = false
    var deviceToken: String?

    private let pushTokenRepo: any PushTokenRepository

    init(pushTokenRepo: any PushTokenRepository = SupabasePushTokenRepository()) {
        self.pushTokenRepo = pushTokenRepo
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Token Registration

    func didRegisterForRemoteNotifications(token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
    }

    func registerTokenWithServer(userId: UUID) async {
        guard let token = deviceToken else { return }
        let insert = PushTokenInsert(userId: userId, token: token, platform: "ios")
        do {
            _ = try await pushTokenRepo.registerToken(insert: insert)
        } catch {
            // Best-effort token registration
        }
    }

    func removeTokenFromServer(userId: UUID) async {
        guard let token = deviceToken else { return }
        do {
            try await pushTokenRepo.removeToken(userId: userId, token: token)
        } catch {
            // Best-effort
        }
    }

    // MARK: - Local Notifications

    func scheduleStreakReminder(hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "Don't forget to log your mood and check in today!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "streak-reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelStreakReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["streak-reminder"])
    }
}
