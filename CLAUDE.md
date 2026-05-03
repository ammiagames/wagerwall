# WagerWall - Project Guide

This is the LLM implementation guide. See `PROJECT.md` for the full specification and `BLOCKING_ARCHITECTURE.md` for the implementation-grade design of the Screen Time + DNS proxy + bloom filter blocking layer (Phase 12).

## Quick Reference

- **Platform**: iOS 17+ (SwiftUI, Xcode 26 beta / Swift 6)
- **Architecture**: MVVM with Repository pattern
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions, Realtime)
- **Auth**: Google OAuth via Supabase Auth (GCP OAuth 2.0 client)
- **Bundle ID**: `com.wagerwall.app`
- **Key Frameworks**: FamilyControls, ManagedSettings, DeviceActivity, NetworkExtension

## Project Structure

```
wagerwall/
├── .gitignore
├── CLAUDE.md                 # This file - LLM guide
├── PROJECT.md                # Full project specification
├── TECH_SPEC.md              # Architecture & technical feasibility
├── Wagerwall/                # Xcode project root
│   ├── Wagerwall.xcodeproj
│   ├── Info.plist            # App Info.plist (reads from xcconfig)
│   ├── Secrets.xcconfig      # Credentials (GITIGNORED - not committed)
│   ├── Secrets.xcconfig.example  # Template for secrets
│   ├── Wagerwall/            # Main app target
│   │   ├── WagerwallApp.swift    # App entry point
│   │   ├── ContentView.swift     # Root view (auth routing)
│   │   ├── Core/             # Shared utilities, extensions, constants
│   │   │   └── Config.swift  # Reads secrets from Bundle/Info.plist
│   │   ├── Models/           # Data models / Supabase table types
│   │   ├── Services/         # Supabase client, auth, blocking, notifications
│   │   │   ├── AuthService.swift
│   │   │   └── SupabaseService.swift
│   │   ├── Repositories/     # Data access layer
│   │   ├── ViewModels/       # MVVM view models
│   │   ├── Views/            # SwiftUI views organized by feature
│   │   │   ├── Auth/         # SignInView
│   │   │   ├── Dashboard/    # DashboardView
│   │   │   ├── Onboarding/
│   │   │   ├── CBT/
│   │   │   ├── Blocking/
│   │   │   ├── Profile/
│   │   │   └── Components/   # Reusable UI components
│   │   └── Resources/        # Assets, Localizable strings, CBT content JSON
│   ├── WagerwallTests/
│   └── WagerwallUITests/
├── supabase/                 # Supabase local config
│   ├── config.toml
│   ├── migrations/           # SQL migrations
│   │   └── 001_initial_schema.sql
│   └── functions/            # Edge functions (Deno/TypeScript)
└── (future) fastlane/        # CI/CD config
```

## Credentials

Secrets are externalized into `Wagerwall/Secrets.xcconfig` (gitignored). To set up:

1. Copy `Wagerwall/Secrets.xcconfig.example` to `Wagerwall/Secrets.xcconfig`
2. Fill in your Supabase and Google OAuth credentials
3. The xcconfig is wired as a base configuration in the Xcode project
4. Values flow: `Secrets.xcconfig` → `Info.plist` via `$(VARIABLE)` → `Config.swift` reads from `Bundle.main.infoDictionary`

## Conventions

- Use SwiftUI for all views; no UIKit unless absolutely necessary
- Prefer `async/await` over Combine for async work
- All Supabase calls go through Repository classes, never directly from ViewModels
- Name files after the primary type they contain (e.g., `CBTLessonView.swift`)
- Keep views small; extract subviews into the `Components/` folder
- Use SwiftUI environment for dependency injection of services
- Edge functions use TypeScript (Deno runtime)
- SQL migrations are numbered: `001_initial_schema.sql`, `002_cbt_content.sql`, etc.

## Commands

```bash
# Supabase local dev
supabase start          # Start local Supabase
supabase db reset       # Reset DB and rerun migrations
supabase functions serve # Run edge functions locally

# iOS (requires DEVELOPER_DIR because xcode-select points to CommandLineTools)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Wagerwall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -project Wagerwall/Wagerwall.xcodeproj
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Wagerwall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -project Wagerwall/Wagerwall.xcodeproj
```

## Implementation Progress

Last verified: 2026-04-28 via subagent audit of source tree.

- [x] **Phase 0**: Project hygiene — deployment target (17.0), bundle ID (com.wagerwall.app), credentials externalized, directory structure, .gitignore
- [x] **Phase 1**: Data models — 14 Codable structs for all DB tables + Insert/Update DTOs + `Assessment`, `Question`, `LessonContent` value types
- [x] **Phase 2**: Repository layer — 10 protocol+Supabase repos, `Dependencies.swift` for SwiftUI environment DI, no stub returns
- [~] **Phase 3**: Navigation architecture — `AppState`, `MainTabView`, `ContentView` routing exist BUT `AppState.swift:28-30` hardcodes `rootScreen = .main` with `// TODO: Re-enable auth flow when sign-in is ready` — auth/onboarding routing is currently bypassed
- [~] **Phase 4**: Onboarding flow — only 2/5 steps wired in `OnboardingViewModel` (`.welcome`, `.screenTime`); PGSI assessment exists as standalone `AssessmentView` in Profile but not in onboarding flow; quit date / spend / completion summary steps missing; `ScreenTimeAuthStepView` is a placeholder (no `FamilyControls` calls)
- [x] **Phase 5**: Dashboard — streak, mood, urge cards wired to real repos; `LogUrgeView`, `LogMoodView`, `BreathingExerciseView` functional
- [x] **Phase 6**: CBT module system — `CBTModulesView`, `CBTModuleDetailView`, `LessonView`, `LessonCompleteView`, full quiz subsystem (MCQ/Matching/Swipe), journal entries via lesson type
- [x] **Phase 7**: Profile and settings — `ProfileView`, `EditProfileView`, `SettingsView`, `AssessmentView`, `CrisisResourcesView` wired
- [x] **Phase 8**: Panic button — `PanicButtonView`, `BreathingExerciseView`, `MotivationalCardView`, view model
- [~] **Phase 9**: Heartbeat + push notifications — iOS side complete (`HeartbeatService` with `BGTaskScheduler` registration, `NotificationService` with APNs token registration to `PushTokenRepository`); backend `send-push` is a stub (no JWT signing, no APNs HTTP/2 call)
- [~] **Phase 10**: Supabase Edge Functions — 4/5 production-ready (`check-heartbeats`, `notify-partner`, `process-disable-request`, `daily-streak-update`); `send-push` requires JWT signing implementation; `notify-partner` email path is logging-only (no Twilio/SendGrid); `003_cron_jobs.sql` jobs are commented out (Pro plan required)
- [~] **Phase 11**: Accountability partners — UI complete (`AccountabilityPartnersView`, `InvitePartnerView`, `DisableProtectionView`, `DisableRequestStatusView`); end-to-end notification path limited until `send-push` is finished
- [ ] **Phase 12**: App & website blocking — **NOT STARTED**. Zero references to `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `NetworkExtension` in source. No `ShieldConfiguration`/`ShieldAction`/`DeviceActivityMonitor` extension targets in pbxproj. Blocked on Apple entitlement application.
- [ ] **Phase 13**: Polish & testing — `WagerwallTests` and `WagerwallUITests` are still default Xcode stubs; zero `accessibilityLabel`/`accessibilityHint` annotations; no `.strings`/`.xcstrings` localization; no `PrivacyInfo.xcprivacy` manifest; no CI/CD; no analytics/Sentry

Legend: `[x]` complete · `[~]` partial (see notes) · `[ ]` not started

### Cross-cutting gaps not tied to a phase

- **Apple Sign-In**: not implemented (only Google OAuth via `AuthService.swift:28-55`). Required by App Store guidelines whenever third-party sign-in is offered.
- **CBT content seed**: `002_cbt_content.sql` seeds only 3 of 8 modules (modules 1–3 from PROJECT.md §5.2). Modules 4–8 (Urge Surfing, Alternative Activities, Financial Recovery, Relapse Prevention, Support Network) still need authoring.
- **Sample vs live data**: Dashboard uses live repos; `Core/SampleData.swift` provides sample CBT modules only.
