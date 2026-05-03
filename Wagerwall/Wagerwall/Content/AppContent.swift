import Foundation

/// Bundled CBT content. Single source of truth for modules, lessons, and questions.
///
/// Content is authored as Swift literals in per-module files (`Module*.swift` in this folder).
/// `AppContent` flattens them into the queryable surface the rest of the app uses.
///
/// User-generated data (progress, attempts, mood/urge logs) lives in Supabase.
/// See `CONTENT_ARCHITECTURE.md` for the design rationale.
enum AppContent {

    // MARK: - Flat collections

    static let modules: [Module] = [
        ModuleUnderstanding.module,
        ModuleCognitive.module,
        ModuleBehavioral.module,
    ].sorted { $0.sortOrder < $1.sortOrder }

    static let lessons: [Lesson] = (
        ModuleUnderstanding.lessons +
        ModuleCognitive.lessons +
        ModuleBehavioral.lessons
    )

    static let questions: [Question] = (
        ModuleUnderstanding.questions +
        ModuleCognitive.questions +
        ModuleBehavioral.questions
    )

    // MARK: - Lookups

    static func module(id: ModuleID) -> Module? {
        modules.first { $0.id == id }
    }

    static func lesson(id: LessonID) -> Lesson? {
        lessons.first { $0.id == id }
    }

    static func question(id: QuestionID) -> Question? {
        questions.first { $0.id == id }
    }

    static func lessons(in moduleId: ModuleID) -> [Lesson] {
        lessons
            .filter { $0.moduleId == moduleId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func questions(in moduleId: ModuleID) -> [Question] {
        questions.filter { $0.moduleId == moduleId }
    }

    static func questions(taggedAny tags: Set<String>) -> [Question] {
        questions.filter { !tags.isDisjoint(with: $0.tags) }
    }
}
