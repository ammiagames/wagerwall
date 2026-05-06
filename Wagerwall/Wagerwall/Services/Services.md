# Services

Cross-cutting integrations: Supabase client, auth, push notifications, background heartbeats. These are the only things that hold long-lived non-repository state.

> **Pattern**: each service is a class (mostly `@Observable` singletons created at app startup) injected via `@Environment` from `WagerwallApp.swift`. Repositories use the global `supabase` client, not the service classes directly.

---

## Files

| File | Purpose |
|---|---|
| `SupabaseService.swift` | Defines the global `let supabase: SupabaseClient` with snake-case + fractional-ISO8601 codecs |
| `AuthService.swift` | Google OAuth via Supabase Auth + session lifecycle. Apple Sign-In TBD |
| `NotificationService.swift` | UNUserNotificationCenter authorization, APNs token registration, local streak reminders |
| `HeartbeatService.swift` | Foreground 5-min timer + `BGAppRefreshTask` for background; pings `device_heartbeats` |

---

## `SupabaseService`

```swift
let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseAnonKey,
    options: SupabaseClientOptions(
        db: .init(encoder: snakeCaseEncoder, decoder: snakeCaseDecoder)
    )
)
```

Two custom codecs:
- **Encoder**: `keyEncodingStrategy = .convertToSnakeCase`, `dateEncodingStrategy = .iso8601`.
- **Decoder**: `keyDecodingStrategy = .convertFromSnakeCase`, custom date decoder that tries fractional-second ISO8601 first, then plain ISO8601 (Supabase returns either depending on the column).

⚠️ Files that use the PostgREST query API (`.select()`, `.value`, etc.) must explicitly `import Supabase` due to `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`.

---

## `AuthService`

```swift
@Observable @MainActor
final class AuthService {
    var session: Session?
    var isAuthenticated: Bool { session != nil }
    var currentUserId: UUID? { session?.user.id ?? Config.devUserId.flatMap(UUID.init) }

    func signInWithGoogle() async throws
    func signOut() async throws
}
```

Flow:
1. `GIDSignIn.sharedInstance.signIn(withPresenting:)` — Google OAuth via the Google SDK to get an ID token.
2. `supabase.auth.signInWithIdToken(credentials:)` — exchange the Google ID token for a Supabase session.
3. Session stored; `AppState.resolveRoute()` (when re-enabled) reads `isAuthenticated` to decide routing.

`currentUserId` falls back to `Config.devUserId` when no session — this is what makes the dev-mode auth bypass work. Views can read user data without a real sign-in.

⚠️ **Apple Sign-In missing**. App Store Guideline 4.8 requires it once Google Sign-In is offered. Implementation: add `import AuthenticationServices`, render `SignInWithAppleButton`, exchange the credential via `supabase.auth.signInWithIdToken(.apple(...))`.

---

## `NotificationService`

```swift
@Observable @MainActor
final class NotificationService {
    var authorizationStatus: UNAuthorizationStatus

    func requestAuthorization() async
    func checkAuthorizationStatus() async
    func registerDeviceToken(_ token: Data) async   // called by AppDelegate.didRegisterForRemoteNotifications
    func removeDeviceToken() async
    func scheduleStreakReminder(at hour: Int = 20, minute: Int = 0)  // local notification
}
```

- Token persistence: hands the hex-encoded APNs token to `PushTokenRepository.registerToken(_:)` to upsert into `push_tokens`.
- Local reminders: schedules a daily local `UNNotificationRequest` at 8pm by default. No backend round-trip for local notifications.
- Remote notifications come through `WagerwallApp.AppDelegate` push delegate methods → routed to this service.

Backend delivery still depends on `supabase/functions/send-push/index.ts`, which is currently a stub (no APNs JWT signing). See `supabase/functions/README.md`.

---

## `HeartbeatService`

```swift
@Observable @MainActor
final class HeartbeatService {
    var lastHeartbeat: Date?

    func start()                 // begin foreground timer
    func stop()                  // pause when app backgrounded
    func registerBackgroundTask() // BGTaskScheduler at app launch
    func sendHeartbeat() async   // upsert (user_id, device_id, last_heartbeat = now())
}
```

Two delivery paths:
1. **Foreground**: `Timer.publish(every: 300)` — every 5 minutes while app is active.
2. **Background**: `BGAppRefreshTask` with identifier `com.wagerwall.app.heartbeat`. iOS schedules these opportunistically (no guaranteed cadence). Permitted via `Info.plist > BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes` includes `fetch`.

`device_id` is `UIDevice.current.identifierForVendor`, persisted in `UserDefaults`. Generates a random UUID fallback if vendor ID is unavailable (no rotation; consider this if dual-install support is ever needed).

The backend reads `device_heartbeats` from `supabase/functions/check-heartbeats/index.ts` (cron, every 15 min). If `last_heartbeat` is older than 45 min, it flags `is_active = false` and notifies the user's accountability partner via `notify-partner` → `send-push`. Stale-detection is the deletion-detection mechanism.

---

## Conventions

- **Service vs Repository**: services are stateful, long-lived, and mostly side-effect-y (auth session, OS callbacks, timers). Repositories are stateless data accessors. If you find yourself adding a method that fetches a row by ID, it belongs in a Repository.
- **Singletons**: services are constructed once in `WagerwallApp.swift` and injected via `@Environment(...)`. Don't reach for `.shared` accessors.
- **MainActor**: every service is `@MainActor`. Off-main work uses `Task` / `await`. Repositories are also MainActor by default (Swift 6 default isolation).
- **No `import SwiftUI`** in this folder. Services are framework-side; views/VMs consume them via the environment.
