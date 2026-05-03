import Foundation
import Supabase

@Observable
final class CBTViewModel {
    var modules: [Module] = []
    var allProgress: [UserLessonProgress] = []
    var lessonsByModule: [ModuleID: [Lesson]] = [:]
    var isLoading = true
    var error: String?

    private let cbtRepo: any CBTRepository

    init(cbtRepo: any CBTRepository) {
        self.cbtRepo = cbtRepo
    }

    // MARK: - Computed

    func completedLessonCount(for moduleId: ModuleID) -> Int {
        let lessonIds = Set((lessonsByModule[moduleId] ?? []).map(\.id))
        return allProgress.filter { lessonIds.contains($0.lessonId) && $0.status == .completed }.count
    }

    func totalLessonCount(for moduleId: ModuleID) -> Int {
        lessonsByModule[moduleId]?.count ?? 0
    }

    func progress(for moduleId: ModuleID) -> Double {
        let total = totalLessonCount(for: moduleId)
        guard total > 0 else { return 0 }
        return Double(completedLessonCount(for: moduleId)) / Double(total)
    }

    func isModuleCompleted(_ moduleId: ModuleID) -> Bool {
        let total = totalLessonCount(for: moduleId)
        return total > 0 && completedLessonCount(for: moduleId) >= total
    }

    func lessonStatus(_ lessonId: LessonID) -> LessonProgressStatus {
        allProgress.first(where: { $0.lessonId == lessonId })?.status ?? .notStarted
    }

    // MARK: - Loading

    func load(userId: UUID) async {
        isLoading = true
        error = nil

        // Content reads are synchronous against bundled data — never fail.
        modules = (try? await cbtRepo.fetchModules()) ?? []
        for module in modules {
            lessonsByModule[module.id] = (try? await cbtRepo.fetchLessons(moduleId: module.id)) ?? []
        }

        // Progress fetch may fail (no network, RLS reject) — non-fatal.
        do {
            allProgress = try await cbtRepo.fetchProgress(userId: userId)
        } catch {
            self.error = error.localizedDescription
            allProgress = []
        }

        isLoading = false
    }

    func refresh(userId: UUID) async {
        await load(userId: userId)
    }

    func didCompleteLesson(_ progress: UserLessonProgress) {
        if let index = allProgress.firstIndex(where: { $0.lessonId == progress.lessonId }) {
            allProgress[index] = progress
        } else {
            allProgress.append(progress)
        }
    }
}
