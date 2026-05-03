import SwiftUI
import GoogleSignIn
import Supabase

@main
struct WagerwallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authService = AuthService()
    @State private var appState: AppState
    @State private var heartbeatService = HeartbeatService()
    @State private var notificationService = NotificationService()

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Config.googleIOSClientID,
            serverClientID: Config.googleWebClientID
        )

        let auth = AuthService()
        _authService = State(initialValue: auth)
        _appState = State(initialValue: AppState(auth: auth))

        HeartbeatService.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(appState)
                .task {
                    appState.start()
                    await notificationService.checkAuthorizationStatus()
                }
                .onChange(of: appState.rootScreen) { _, newScreen in
                    if newScreen == .main, let userId = authService.session?.user.id {
                        heartbeatService.startForegroundHeartbeat(userId: userId)
                        HeartbeatService.scheduleBackgroundTask()
                        Task { await notificationService.registerTokenWithServer(userId: userId) }
                    } else if newScreen == .signIn {
                        heartbeatService.stopForegroundHeartbeat()
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - AppDelegate for Push Notifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Store token for later registration
        UserDefaults.standard.set(tokenString, forKey: "wagerwall_apns_token")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push registration failed — non-critical
    }

    // Handle foreground notifications
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification actions in the future
    }
}
