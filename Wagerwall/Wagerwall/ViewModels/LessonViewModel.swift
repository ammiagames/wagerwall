import Foundation
import Supabase

@Observable
final class LessonViewModel {
    let lesson: Lesson
    var progress: UserLessonProgress?
    var currentSectionIndex: Int = 0
    var questionResults: [QuestionID: Bool] = [:]   // questionId -> correct?
    var journalEntries: [Int: String] = [:]         // section index -> text
    var isSaving = false
    var isCompleted = false
    var error: String?

    private let cbtRepo: any CBTRepository
    private let userId: UUID

    init(lesson: Lesson, userId: UUID, cbtRepo: any CBTRepository) {
        self.lesson = lesson
        self.userId = userId
        self.cbtRepo = cbtRepo
    }

    // MARK: - Computed

    var sections: [LessonSection] { lesson.sections }

    var totalSections: Int { sections.count }

    var isLastSection: Bool { currentSectionIndex >= totalSections - 1 }

    var currentSection: LessonSection? {
        guard sections.indices.contains(currentSectionIndex) else { return nil }
        return sections[currentSectionIndex]
    }

    var canAdvance: Bool {
        guard let section = currentSection else { return false }
        switch section {
        case .text, .callout:
            return true
        case .question(let qid):
            return questionResults[qid] != nil
        case .journal:
            let entry = journalEntries[currentSectionIndex] ?? ""
            return !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var sectionProgress: Double {
        guard totalSections > 0 else { return 0 }
        return Double(currentSectionIndex + 1) / Double(totalSections)
    }

    /// Number of question sections in this lesson (denominator for quiz score).
    var totalQuestions: Int {
        sections.reduce(0) { count, section in
            if case .question = section { return count + 1 }
            return count
        }
    }

    var correctAnswerCount: Int {
        questionResults.values.filter { $0 }.count
    }

    // MARK: - Recording answers

    func recordAnswer(questionId: QuestionID, isCorrect: Bool) {
        questionResults[questionId] = isCorrect
    }

    // MARK: - Navigation

    func advance() {
        if isLastSection {
            Task { await completeLesson() }
        } else {
            currentSectionIndex += 1
        }
    }

    func goBack() {
        if currentSectionIndex > 0 {
            currentSectionIndex -= 1
        }
    }

    // MARK: - Progress persistence

    func markStarted() async {
        do {
            let insert = UserLessonProgressInsert(
                userId: userId,
                lessonId: lesson.id,
                status: .inProgress,
                startedAt: Date()
            )
            progress = try await cbtRepo.upsertProgress(insert: insert)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func completeLesson() async {
        isSaving = true
        error = nil

        do {
            let journalArray = journalEntries.sorted(by: { $0.key < $1.key }).map(\.value)
            let totalQs = totalQuestions

            let exerciseData = ExerciseData(
                journalEntries: journalArray.isEmpty ? nil : journalArray,
                quizScore: totalQs > 0 ? correctAnswerCount : nil,
                quizTotal: totalQs > 0 ? totalQs : nil
            )

            if let existingProgress = progress {
                let update = UserLessonProgressUpdate(
                    status: .completed,
                    completedAt: Date(),
                    exerciseData: exerciseData
                )
                progress = try await cbtRepo.updateProgress(progressId: existingProgress.id, update: update)
            } else {
                let insert = UserLessonProgressInsert(
                    userId: userId,
                    lessonId: lesson.id,
                    status: .completed,
                    startedAt: Date()
                )
                var created = try await cbtRepo.upsertProgress(insert: insert)
                let update = UserLessonProgressUpdate(
                    status: .completed,
                    completedAt: Date(),
                    exerciseData: exerciseData
                )
                created = try await cbtRepo.updateProgress(progressId: created.id, update: update)
                progress = created
            }

            isCompleted = true
        } catch {
            // Persistence failed (likely auth disabled / RLS reject). Still complete locally.
            self.error = error.localizedDescription
            isCompleted = true
        }

        isSaving = false
    }
}
