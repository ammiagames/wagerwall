# ViewModels

`@Observable` classes that hold UI state and orchestrate repository calls. One VM per significant screen or flow. No SwiftUI imports here.

> **Pattern**: VMs hold repositories by protocol (injected at construction), expose state with `@Observable`, parallelize independent fetches with `async let`, and surface error strings as `var errorMessage: String?`.

---

## Files (9 view models)

| File | Owns | Used by |
|---|---|---|
| `OnboardingViewModel.swift` | Step state machine (currently `welcome` + `screenTime` only) | `Views/Onboarding/OnboardingContainerView` |
| `DashboardViewModel.swift` | Streak, mood, urges, money saved, daily quote | `Views/Dashboard/DashboardView` |
| `CBTViewModel.swift` | Modules + lessons + per-user progress aggregation | `Views/CBT/CBTModulesView` |
| `LessonViewModel.swift` | Lesson section walker, question results, journal entries, completion | `Views/CBT/LessonView`, `LessonCompleteView` |
| `QuizSessionViewModel.swift` | Standalone quiz (no lesson context) — index, streak, score | `Views/CBT/Quiz/QuizSessionView` |
| `PanicButtonViewModel.swift` | 3-step crisis flow (breathing → motivation → outcome) | `Views/Dashboard/PanicButtonView` |
| `MoodLogViewModel.swift` | Mood entry form (1–5 + notes) | `Views/Dashboard/LogMoodView` |
| `UrgeLogViewModel.swift` | Urge entry form (intensity, trigger, coping, outcome) | `Views/Dashboard/LogUrgeView` |
| `AccountabilityPartnerViewModel.swift` | Partner list + disable request lifecycle | `Views/Profile/AccountabilityPartnersView`, `DisableProtectionView` |

---

## Pattern

```swift
@Observable @MainActor
final class DashboardViewModel {
    private let userProfileRepo: UserProfileRepository
    private let streakRepo: StreakRepository
    private let urgeRepo: UrgeLogRepository
    private let moodRepo: MoodLogRepository

    var profile: UserProfile?
    var streak: UserStreak?
    var todaysUrges: [UrgeLog] = []
    var todaysMood: MoodLog?
    var isLoading = false
    var errorMessage: String?

    init(userProfileRepo: UserProfileRepository, ...) {
        self.userProfileRepo = userProfileRepo
        // ...
    }

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let profile = userProfileRepo.fetchProfile(id: userId)
            async let streak = streakRepo.fetchStreak(userId: userId)
            async let urges = urgeRepo.fetchLogs(userId: userId)
            async let mood = moodRepo.fetchTodaysLog(userId: userId)
            (self.profile, self.streak, self.todaysUrges, self.todaysMood) =
                try await (profile, streak, urges, mood)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Local-mutation callbacks for sheets that complete
    func didLogUrge(_ log: UrgeLog) { todaysUrges.insert(log, at: 0) }
}
```

- **Repos by protocol** so previews/tests can inject mocks.
- **Computed properties** for derived UI strings (greeting, streak message, money-saved formatter) — keeps views dumb.
- **`load()` is idempotent**: views call it from `.task { await vm.load(userId: …) }`; safe to retry on appear.

---

## `OnboardingViewModel` — currently 2 steps only

```swift
enum OnboardingStep: CaseIterable { case welcome, screenTime }
```

The PROJECT.md spec calls for 5 steps (welcome → assessment → quit date / spend → screen time → completion). Today the assessment lives standalone in `Views/Profile/AssessmentView` and the rest aren't built. `ScreenTimeAuthStepView` is itself a placeholder — no `FamilyControls.AuthorizationCenter.requestAuthorization(for: .individual)` call yet.

To extend the flow, add the new case here, write the corresponding step view in `Views/Onboarding/`, and route it in `OnboardingContainerView`.

---

## `LessonViewModel` — section state machine

A lesson is an ordered `[LessonSection]` (text, callout, question by ID, journal). The VM tracks:
- `currentSectionIndex`
- `questionResults: [QuestionID: Bool]` (right/wrong)
- `journalEntries: [Int: String]` (per-section index)
- `isCompleted: Bool`

`canAdvance` validates the current section type — e.g., a journal section requires non-empty text; a question section requires an answer. Completion writes `UserLessonProgressInsert` with `exerciseData` (journal array + quiz score).

Lesson IDs are slugs (`"lesson-gamblers-fallacy"`), persisted as `TEXT` after migration `004_decouple_content.sql`.

---

## `PanicButtonViewModel` — crisis flow shortcut

3-step wizard:
1. `.breathing` — `BreathingExerciseView` runs a guided 4-7-8 timer.
2. `.motivation` — `MotivationalCardView` shows a quote (10 hardcoded options).
3. `.outcome` — user selects `resisted`, `gaveIn`, or `usedPanicButton`.

`logAndComplete()` writes a `UrgeLogInsert` with `intensity = 8` (hardcoded — not user-input) and a `coping_strategy_used = "panic_button"` tag. Future improvement: let the user grade their own intensity post-flow.

---

## `AccountabilityPartnerViewModel`

Holds two related but distinct concerns:
1. **Partner CRUD** — `activePartners`, `invitedPartners`, `invitePartner(email:)`, `removePartner(_:)`.
2. **Disable request lifecycle** — `hasActiveDisableRequest`, `cooloffTimeRemaining`, `requestDisableProtection(cooloffHours: 24)`, `cancelDisableRequest()`.

These are bundled because both views (`AccountabilityPartnersView`, `DisableProtectionView`) need both states. Could be split if either view becomes complex.

The cooling-off timer is a UI countdown; the actual expiration is enforced by `supabase/functions/process-disable-request/index.ts`.

---

## Conventions

- **`@Observable @MainActor`** on every VM.
- **`async let` for parallel fetches** — never serialize independent reads.
- **`errorMessage: String?`** — surface failures to the view as a banner; don't `try!` and crash.
- **No SwiftUI imports** — VMs compile against Foundation + Supabase only.
- **Computed UI strings live in the VM**, not in the view (greeting, "8 days strong", "$120 saved").
- **Initializers take repositories**, not the SwiftUI environment — makes VMs unit-testable in isolation.
