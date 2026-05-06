# Views

SwiftUI screens grouped by feature. ~43 view files. Views own a VM (or pull repos directly for very small screens), render UI, and forward user actions back to the VM.

> **Pattern**: views never call Supabase. They pull repos from `@Environment(\.repoName)` only to construct a VM (`@State private var vm = MyVM(repo: repo)`), or — for the simplest screens — bind directly to a single repo call.

---

## Folder layout

| Folder | Files | What's there |
|---|---|---|
| `Auth/` | `SignInView` | Google Sign-In button + branding |
| `Onboarding/` | `OnboardingContainerView`, `WelcomeStepView`, `ScreenTimeAuthStepView` | 2-step onboarding flow (more steps TBD) |
| `Dashboard/` | `MainTabView`, `DashboardView`, `LogMoodView`, `LogUrgeView`, `PanicButtonView`, `BreathingExerciseView`, `MotivationalCardView`, `ProgressTabView` | Home tab + the entry points it presents as sheets / full-screen |
| `CBT/` | `CBTModulesView`, `CBTModuleDetailView`, `LessonView`, `LessonCompleteView` + `Quiz/` | Learn tab |
| `CBT/Quiz/` | `QuizSessionView`, `MultipleChoiceView`, `MultipleSelectView`, `TrueFalseView`, `FillInBlankView`, `MatchingView`, `SortOrderView`, `SwipeCategorizeView`, `QuizCompleteView`, `FlowLayout`, `QuizCellStyle`, `UnsupportedQuestionPlaceholder` | Question renderers — one view per `Question.Payload` case |
| `Profile/` | `ProfileView`, `EditProfileView`, `AssessmentView`, `AccountabilityPartnersView`, `InvitePartnerView`, `DisableProtectionView`, `DisableRequestStatusView`, `CrisisResourcesView`, `SettingsView` | More tab — settings, partnerships, PGSI assessment, crisis hotlines |
| `Components/` | `CardView`, `WaveDecoration`, `WagerWallButton`, `ProgressStepIndicator`, `StatCard`, `ThemedBackground` | Reusable building blocks |
| `Blocking/` | (empty) | Placeholder folder — Phase 12 not started |

---

## Tab structure (`MainTabView`)

4 tabs. Liquid-glass tab bar (iOS 26) configured via UIKit appearance, not SwiftUI `.toolbarBackground`:

```swift
init() {
    let tabAppearance = UITabBarAppearance()
    tabAppearance.configureWithTransparentBackground()
    UITabBar.appearance().standardAppearance = tabAppearance
    UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    // similar for UINavigationBarAppearance
}
```

| Tab | Root view | Purpose |
|---|---|---|
| Home | `DashboardView` | Streak, mood/urge logging, panic button |
| Learn | `CBTModulesView` | CBT modules + lessons + quizzes |
| Progress | `ProgressTabView` | Trends and history (visualization depth TBD) |
| More | `ProfileView` | Settings, partners, assessment, crisis resources |

Each tab is wrapped in a `tabPage(...)` helper that adds `Theme.background` + `WaveDecoration` inside its `NavigationStack`. **Background must be inside the stack** — NavigationStack is opaque and would cover anything placed behind it.

---

## Theming

- **`Theme.background`** — dark purple, applied as the first child inside every `NavigationStack`.
- **`WaveDecoration`** — three overlapping circles at the bottom that bleed behind the tab bar via `.ignoresSafeArea(edges: .bottom)`. Don't add `.clipped()` — it cuts off the wave.
- **`UINavigationBarAppearance` + `UITabBarAppearance`** must be `configureWithTransparentBackground()` — the SwiftUI `.toolbarBackground(.hidden)` modifier does not work with iOS 26 liquid glass.
- **`Tab(_:systemImage:content:)` is iOS 18+**. We target iOS 17 — use `.tabItem { Label("…", systemImage: "…") }`.

---

## Quiz subsystem (`Views/CBT/Quiz/`)

Each `Question.Payload` case has a dedicated renderer. Adding a new question type means:
1. Add a case to `Question.Payload` in `Models/Question.swift`.
2. Add a renderer view in this folder.
3. Wire it into `QuizSessionView`'s switch.

Helpers:
- `FlowLayout` — custom `Layout` for word-bank flow (used by `FillInBlankView` in `wordBank` mode).
- `QuizCellStyle` — shared button styling (correct/incorrect/neutral states).
- `UnsupportedQuestionPlaceholder` — fallback when an unknown payload comes through (currently impossible without a binary mismatch, but kept defensively).

---

## Sheets vs full-screen

- **Sheets** (`.sheet(isPresented:)`): `LogMoodView`, `LogUrgeView`, `InvitePartnerView`. Quick form-style inputs.
- **Full-screen covers** (`.fullScreenCover(isPresented:)`): `PanicButtonView`. Crisis flow needs full attention; tab bar must not be visible.
- **Push** (`NavigationLink`): everything in `Profile/`, lesson detail flow.

---

## Empty placeholder: `Blocking/`

This folder exists but is empty. The Phase 12 blocking layer (Screen Time API + DNS proxy) is not started. When work begins:

- App-blocking UI (FamilyActivityPicker, blocked-list management, schedule editor) → here.
- Shield extension UI lives in a **separate Xcode target** (not yet created), not under Views/.

See `BLOCKING_ARCHITECTURE.md` (root) for the design and `TECH_SPEC.md` for the entitlement strategy.

---

## Accessibility

⚠️ **Zero accessibility annotations** in this folder today. No `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, `accessibilityElement(children:)`. VoiceOver works only because SwiftUI auto-derives labels for stock controls — anything custom (panic button, wave decoration, custom progress dots) is invisible to assistive tech.

This is Phase 13 (Polish) territory but worth fixing alongside any view you touch.

---

## Components glossary (`Components/`)

| Component | Use it for |
|---|---|
| `CardView<Content>` | Generic dark-purple card container with corner radius + padding |
| `WaveDecoration` | The three-circle gradient flourish at the bottom of every tab |
| `WagerWallButton` | Primary CTA — branded purple background, white text |
| `ProgressStepIndicator` | Dot indicator for multi-step flows (onboarding, lesson sections) |
| `StatCard` | KPI tile (label + value + optional unit) — used on dashboard |
| `ThemedBackground` | Wraps content in `Theme.background.ignoresSafeArea()` |

If you build a new view that wants the same styling as an existing one, check here first. If you build a third copy of similar styling, extract a Component.

---

## Conventions

- **One view per file**, named to match the primary type (`LogUrgeView.swift` ⇒ `struct LogUrgeView`).
- **Subviews** that are only used by one parent → file-private at the bottom of the parent's file. Cross-file subviews → `Components/` if reused, otherwise their own file.
- **State ownership**: the screen-level view owns its VM via `@State`. Sheet/cover children get their VM passed in or constructed inline.
- **Repos via `@Environment`**, never Supabase directly. If your view needs to fetch something, build a VM.
- **Don't fight liquid glass**: any time you're tempted to use `.toolbarBackground(.hidden)`, you actually want UIKit appearance + transparent NavigationStack background.
