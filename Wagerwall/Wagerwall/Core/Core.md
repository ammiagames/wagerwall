# Core

App-wide infrastructure: state machine, dependency injection, configuration, theme. Imported by everything; should depend on nothing in `Views/` or `ViewModels/`.

---

## Files

| File | Type | Role |
|---|---|---|
| `AppState.swift` | `@Observable` class + `enum RootScreen` | Routes the root view based on auth/onboarding state |
| `Config.swift` | enum (static) | Reads typed values from `Bundle.main.infoDictionary` (populated from `Secrets.xcconfig` via `Info.plist` `$(VAR)` substitution) |
| `Dependencies.swift` | `EnvironmentValues` extensions | Defines an `@Environment` key for each of the 10 repository protocols |
| `Theme.swift` | enum (static) | Color constants for the dark-purple theme (background, hero card, wave circles, tab tint) |

---

## `AppState`

State machine for which root screen to show.

```swift
enum RootScreen { case loading, signIn, onboarding, main }

@Observable @MainActor
final class AppState {
    var rootScreen: RootScreen = .loading
    func start() async { ... }
    func completeOnboarding() { ... }
    func didSignOut() { ... }
    private func resolveRoute() async { ... }   // queries auth + user_profiles.onboarding_completed
}
```

⚠️ **Auth bypass active**. `start()` currently does:

```swift
// AppState.swift:28-30
// TODO: Re-enable auth flow when sign-in is ready
rootScreen = .main
```

The full `resolveRoute()` logic (check `AuthService.isAuthenticated`, fetch `UserProfile.onboardingCompleted`, route to `.signIn` / `.onboarding` / `.main`) is dead code until that line is removed. To re-enable: delete the hardcoded line, uncomment the `await resolveRoute()` call, and confirm `AuthService.signInWithGoogle()` end-to-end before merging.

`AppState` is created in `WagerwallApp.swift` and injected via `@Environment(AppState.self)`. `ContentView.swift` switches on `rootScreen` to render `ProgressView` / `SignInView` / `OnboardingContainerView` / `MainTabView`.

---

## `Config`

Static accessors that read from `Info.plist` (which is populated from `Secrets.xcconfig` at build time via `$(VAR_NAME)` substitution).

```swift
enum Config {
    static var supabaseURL: URL          // SUPABASE_URL
    static var supabaseAnonKey: String   // SUPABASE_ANON_KEY
    static var googleIOSClientID: String // GOOGLE_IOS_CLIENT_ID
    static var googleWebClientID: String // GOOGLE_WEB_CLIENT_ID
    static var devUserId: String?        // DEV_USER_ID (optional fallback for auth-bypass)
}
```

`fatalError` on missing values — fail loudly during development. To add a new secret:
1. Add to `Wagerwall/Secrets.xcconfig.example` (and your local `Secrets.xcconfig`).
2. Add an `Info.plist` entry that references it: `<key>MY_KEY</key><string>$(MY_KEY)</string>`.
3. Add a static accessor here.

---

## `Dependencies`

Each repository protocol gets an `EnvironmentKey` + a typed `EnvironmentValues` accessor so views/VMs can pull repos without singletons:

```swift
extension EnvironmentValues {
    var userProfileRepository: UserProfileRepository { ... }
    var streakRepository: StreakRepository { ... }
    var cbtRepository: CBTRepository { ... }
    var urgeLogRepository: UrgeLogRepository { ... }
    var moodLogRepository: MoodLogRepository { ... }
    var heartbeatRepository: HeartbeatRepository { ... }
    var accountabilityPartnerRepository: AccountabilityPartnerRepository { ... }
    var blockedAttemptRepository: BlockedAttemptRepository { ... }
    var disableRequestRepository: DisableRequestRepository { ... }
    var pushTokenRepository: PushTokenRepository { ... }
}
```

`WagerwallApp.swift` injects concrete `Supabase`-backed implementations via `.environment(\.userProfileRepository, ...)` etc. on the root view. SwiftUI Previews can inject mocks the same way.

To add a new repository:
1. Define the protocol + Supabase impl in `Repositories/`.
2. Add an `EnvironmentKey` and accessor here.
3. Inject the concrete instance in `WagerwallApp.swift`.
4. Pull from `@Environment(\.myRepo) var repo` in views/VMs.

---

## `Theme`

Hardcoded RGB values (no light-mode support yet). The app is intentionally dark-purple-only for brand identity.

```swift
enum Theme {
    static let background     // dark purple
    static let waveLeft, waveCenter, waveRight  // circle fills for WaveDecoration
    static let heroCard       // dashboard hero gradient color
    static let tabActive      // active tab tint
}
```

If you add a new color, put it here — don't scatter `Color(red:green:blue:)` literals across views.

---

## What does NOT belong here

- Anything that imports SwiftUI views (`Views/`), Supabase SDK (`Services/`, `Repositories/`), or framework-specific extensions like FamilyControls.
- Mutable singletons. `AppState` is the only `@Observable` here, and it's owned by the SwiftUI environment, not held statically.
- Feature-specific business logic — that goes in a `ViewModel` or `Repository`.
