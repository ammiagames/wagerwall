# Content

Bundled CBT modules, lessons, and questions. Authored as Swift literals — ships in the app binary, works offline, scales free.

> **Read [`CONTENT_ARCHITECTURE.md`](../../../CONTENT_ARCHITECTURE.md) first** for the design rationale (why Swift not JSON, why questions are top-level, why slugs not UUIDs).

---

## Files

| File | Purpose |
|---|---|
| `AppContent.swift` | Aggregator — flattens per-module files into `modules`, `lessons`, `questions` arrays + lookup helpers |
| `ModuleUnderstanding.swift` | Module 1: "Understanding Gambling" (lessons + questions) |
| `ModuleCognitive.swift` | Module 2: "Cognitive Distortions" |
| `ModuleBehavioral.swift` | Module 3: "Behavioral Coping" |

⚠️ **Modules 4–8 not authored yet** (Urge Surfing, Alternative Activities, Financial Recovery, Relapse Prevention, Support Network). When adding them, create one file per module here and append to the `AppContent` aggregator.

---

## `AppContent` — the consumer-facing surface

The rest of the app talks only to this enum. Per-module files are an authoring detail.

```swift
enum AppContent {
    static let modules: [Module]        // sorted by sortOrder
    static let lessons: [Lesson]        // flattened from all module files
    static let questions: [Question]    // flattened from all module files

    static func module(id: ModuleID) -> Module?
    static func lesson(id: LessonID) -> Lesson?
    static func question(id: QuestionID) -> Question?
    static func lessons(in moduleId: ModuleID) -> [Lesson]
    static func questions(in moduleId: ModuleID) -> [Question]
    static func questions(taggedAny: Set<String>) -> [Question]
}
```

`CBTRepository.fetchModules() / fetchLessons() / fetchLesson(id:)` reads directly from this. Per-user lesson progress still flows through Supabase.

---

## Authoring a new lesson

A complete module file looks like this:

```swift
enum ModuleUnderstanding {
    static let module = Module(
        id: "module-understanding",
        title: "Understanding Gambling",
        description: "...",
        sortOrder: 1,
        estimatedMinutes: 30,
        iconName: "brain.head.profile"   // SF Symbol
    )

    static let lessons: [Lesson] = [
        Lesson(
            id: "lesson-gamblers-fallacy",
            moduleId: "module-understanding",
            title: "The Gambler's Fallacy",
            description: "...",
            sortOrder: 2,
            estimatedMinutes: 10,
            sections: [
                .text(title: "What is it?", body: "..."),
                .callout(style: .example, body: "..."),
                .question("q-fallacy-roulette"),       // by-reference
                .text(title: nil, body: "..."),
                .question("q-fallacy-streaks"),
                .journal(prompt: "Write about a time you felt a 'lucky streak.'")
            ]
        ),
        // ...
    ]

    static let questions: [Question] = [
        Question(
            id: "q-fallacy-roulette",
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 1,
            prompt: "...",
            explanation: "...",
            payload: .multipleChoice(options: [...], correctIndex: 2)
        ),
        // ...
    ]
}
```

Then register it in `AppContent.swift`:

```swift
static let modules: [Module] = [
    ModuleUnderstanding.module,
    ModuleCognitive.module,
    ModuleBehavioral.module,
    // append new module here
].sorted(by: { $0.sortOrder < $1.sortOrder })

static let lessons: [Lesson] = [
    ModuleUnderstanding.lessons,
    ModuleCognitive.lessons,
    ModuleBehavioral.lessons,
    // append
].flatMap { $0 }

static let questions: [Question] = [
    ModuleUnderstanding.questions,
    ModuleCognitive.questions,
    ModuleBehavioral.questions,
    // append
].flatMap { $0 }
```

---

## ID rules

- **Module IDs**: `module-{topic}` (e.g., `module-understanding`).
- **Lesson IDs**: `lesson-{topic}` (e.g., `lesson-gamblers-fallacy`).
- **Question IDs**: `q-{topic}-{detail}` (e.g., `q-fallacy-roulette`).

**Permanent once shipped.** Renaming a slug after release silently corrupts user progress (`user_lesson_progress` rows still reference the old slug; the app skips orphans). Add new IDs; don't reuse old ones.

---

## Question payload variants

`Question.Payload` (defined in `Models/Question.swift`) has 7 cases:

| Case | What it tests |
|---|---|
| `multipleChoice` | Pick one of N |
| `multipleSelect` | Pick all that apply |
| `trueFalse` | Boolean |
| `fillInBlank(template, acceptedAnswers, mode)` | Type into blanks (free-type or word-bank) |
| `matching(pairs)` | Match left column to right column |
| `sortOrder(items)` | Reorder a list |
| `swipeCategorize(leftLabel, rightLabel, cards)` | Tinder-style left/right categorization |

Each renders via a dedicated view in `Views/CBT/Quiz/` (e.g., `MultipleChoiceView`, `SwipeCategorizeView`). To add an 8th type: add a case to `Payload`, add a renderer, fix every switch the compiler complains about.

---

## Tags & spaced repetition (forward-compatible)

`Question.tags: [String]` exists but isn't used yet. The intent (per `CONTENT_ARCHITECTURE.md` §"Spaced repetition") is a Leitner-box review mode that pulls questions by tag across modules:

- `mastery_level: 0..5` per (user, question) — stored in a future `user_question_state` table.
- Wrong → drop a level; right → +1 level, double the interval.
- 1d → 2d → 4d → 8d → 16d → 32d → mastered.

Schema for `question_attempts` and `user_question_state` is sketched in `CONTENT_ARCHITECTURE.md`; not yet migrated.

---

## What does NOT belong here

- **User-generated data** (journal entries, mood logs, urge logs, profile fields). Those go to Supabase via repositories.
- **Media assets** (images, audio). Currently no media is bundled — text-only lessons. If/when audio narration is added, bundle MP3s in `Resources/` (not here) or stream from Supabase Storage.
- **Localized strings**. Not yet wired (`.strings`/`.xcstrings` missing). When localization happens, lesson copy moves out of these literals into LocalizedStringResource lookups.
