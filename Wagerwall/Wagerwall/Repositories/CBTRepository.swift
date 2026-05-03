import Foundation
import Supabase

/// Reads CBT module / lesson content from `AppContent` (bundled in app).
/// Reads / writes user progress against Supabase (per-user data).
protocol CBTRepository: Sendable {
    func fetchModules() async throws -> [Module]
    func fetchLessons(moduleId: ModuleID) async throws -> [Lesson]
    func fetchLesson(lessonId: LessonID) async throws -> Lesson?
    func fetchProgress(userId: UUID) async throws -> [UserLessonProgress]
    func fetchLessonProgress(userId: UUID, lessonId: LessonID) async throws -> UserLessonProgress?
    func upsertProgress(insert: UserLessonProgressInsert) async throws -> UserLessonProgress
    func updateProgress(progressId: UUID, update: UserLessonProgressUpdate) async throws -> UserLessonProgress
}

struct SupabaseCBTRepository: CBTRepository {

    // MARK: - Content (bundled, no network)

    func fetchModules() async throws -> [Module] {
        AppContent.modules
    }

    func fetchLessons(moduleId: ModuleID) async throws -> [Lesson] {
        AppContent.lessons(in: moduleId)
    }

    func fetchLesson(lessonId: LessonID) async throws -> Lesson? {
        AppContent.lesson(id: lessonId)
    }

    // MARK: - Progress (Supabase)

    func fetchProgress(userId: UUID) async throws -> [UserLessonProgress] {
        try await supabase.from("user_lesson_progress")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func fetchLessonProgress(userId: UUID, lessonId: LessonID) async throws -> UserLessonProgress? {
        let results: [UserLessonProgress] = try await supabase.from("user_lesson_progress")
            .select()
            .eq("user_id", value: userId)
            .eq("lesson_id", value: lessonId)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func upsertProgress(insert: UserLessonProgressInsert) async throws -> UserLessonProgress {
        try await supabase.from("user_lesson_progress")
            .upsert(insert, onConflict: "user_id,lesson_id")
            .select()
            .single()
            .execute()
            .value
    }

    func updateProgress(progressId: UUID, update: UserLessonProgressUpdate) async throws -> UserLessonProgress {
        try await supabase.from("user_lesson_progress")
            .update(update)
            .eq("id", value: progressId)
            .select()
            .single()
            .execute()
            .value
    }
}
