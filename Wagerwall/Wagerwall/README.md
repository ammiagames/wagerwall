# Wagerwall iOS App

The main iOS app target. SwiftUI, Swift 6, iOS 17+ minimum, MVVM + Repository, Supabase backend.

> **For LLMs ramping up**: this file is the entry point. Each subfolder has a focused doc — read the ones you need rather than this whole tree.

---

## Layout

```
Wagerwall/
├── WagerwallApp.swift          @main; wires AuthService, AppState, HeartbeatService, NotificationService
├── ContentView.swift           Root router; switch on AppState.rootScreen
├── Info.plist                  Background modes, BGTask IDs, $(VAR) substitutions
│
├── Core/         (4 files)     App state machine, dependency injection, config, theme
│                               → Core/Core.md
├── Models/       (15 files)    Codable structs that map 1:1 to Supabase tables
│                               → Models/Models.md
├── Services/     (4 files)     Cross-cutting integrations: auth, Supabase, notifications, heartbeat
│                               → Services/Services.md
├── Repositories/ (10 files)    Protocol + Supabase impl per table; the only thing that talks to Supabase
│                               → Repositories/Repositories.md
├── ViewModels/   (9 files)     @Observable VMs; no SwiftUI imports, no direct Supabase
│                               → ViewModels/ViewModels.md
├── Views/        (43 files)    SwiftUI screens grouped by feature (Auth, Onboarding, Dashboard, CBT, Profile, Components)
│                               → Views/Views.md
├── Content/      (4 files)     Bundled CBT modules + lessons + questions (Swift literals, offline-first)
│                               → Content/Content.md
└── Resources/    (1 file)      Assessment.json (PGSI questionnaire)
```

---

## Architecture

```
View (SwiftUI)
   │ @State / @Environment
   ▼
ViewModel (@Observable)
   │ holds repository protocols
   ▼
Repository (protocol + Supabase impl)
   │
   ▼
Supabase Swift SDK    or    AppContent (bundled Swift content)
```

- **Views** never call Supabase directly. They get repositories from `@Environment(\.repoName)` (defined in `Core/Dependencies.swift`).
- **ViewModels** hold repositories by protocol, expose `@Observable` state, and orchestrate async work with `async let` for parallel fetches.
- **Repositories** are the only layer that imports `Supabase`. Each is a protocol + a `Supabase`-backed struct.
- **Content** (CBT lessons/questions) is compiled into the binary — `CBTRepository` reads from `AppContent` for content, Supabase only for per-user progress.

---

## Entry flow

`WagerwallApp.swift`:
1. Configures `GIDSignIn` from `Config.googleIOSClientID`.
2. Registers `BGAppRefreshTask` handler for `com.wagerwall.app.heartbeat`.
3. Constructs `AuthService`, `AppState`, `HeartbeatService`, `NotificationService` and injects them via `@Environment` along with all 10 repositories.
4. Renders `ContentView`, which switches on `appState.rootScreen` (`.loading`, `.signIn`, `.onboarding`, `.main`).

⚠️ **Auth bypass active**: `Core/AppState.swift:30` hardcodes `rootScreen = .main` behind a `// TODO: Re-enable auth flow when sign-in is ready` comment. The auth/onboarding routing logic exists but is disabled. Re-enabling is a prerequisite to closing Phase 1.

---

## External dependencies

Linked via Swift Package Manager (see `Wagerwall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`):

| Package | Version | Used by |
|---|---|---|
| supabase-swift | 2.41.1 | `Services/SupabaseService.swift`, all repositories |
| GoogleSignIn-iOS | 9.1.0 | `Services/AuthService.swift`, `WagerwallApp.swift` |

Apple frameworks imported by feature:
- `BackgroundTasks` — `Services/HeartbeatService.swift`, `WagerwallApp.swift`
- `UserNotifications` — `Services/NotificationService.swift`, `WagerwallApp.swift`
- `UIKit` — `Services/AuthService.swift`, `Views/Dashboard/MainTabView.swift` (UINavigationBarAppearance for liquid-glass tab bar)

⚠️ **Not yet imported anywhere** (Phase 12 blocking layer not started): `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `NetworkExtension`. No `ShieldConfiguration`/`ShieldAction`/`DeviceActivityMonitor` extension targets exist either.

---

## Conventions specific to this target

- **`PBXFileSystemSynchronizedRootGroup`**: files in this folder are auto-discovered by Xcode. Two files with the same name in different subdirs cause "duplicate output file" errors. That's why per-folder docs use unique names (`Models.md`, `Services.md`, …) rather than `README.md`.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** + **`SWIFT_APPROACHABLE_CONCURRENCY = YES`** are set project-wide. Most types are MainActor-isolated by default; mark async code `nonisolated` or hop explicitly when needed.
- **`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`**: any file that uses Supabase PostgREST query API (`.select()`, `.value`, etc.) must explicitly `import Supabase`.
- **Snake-case JSON**: `SupabaseService.swift` configures custom encoder/decoder strategies; Codable structs use camelCase property names that map automatically.
- **`Tab(_:systemImage:content:)` is iOS 18+**. We target iOS 17 — use `.tabItem { Label(...) }`.

---

## Build & run

From the repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme Wagerwall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -project Wagerwall/Wagerwall.xcodeproj \
  build
```

Tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Wagerwall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -project Wagerwall/Wagerwall.xcodeproj
```

`WagerwallTests/` and `WagerwallUITests/` are still default Xcode template stubs — no real coverage yet.

---

## Common tasks → start here

| Goal | First file to read |
|---|---|
| Add a new screen | `Views/Views.md` |
| Add or change a Supabase table mapping | `Models/Models.md`, `Repositories/Repositories.md` |
| Add a new edge function call | `Repositories/Repositories.md` |
| Add a CBT lesson or question | `Content/Content.md` |
| Re-enable auth routing | `Core/Core.md` (AppState section) |
| Wire up Phase 12 blocking | `BLOCKING_ARCHITECTURE.md` (root) — extension targets do not yet exist |
| Configure a new credential | `Core/Core.md` (Config section) + `Wagerwall/Secrets.xcconfig.example` |
