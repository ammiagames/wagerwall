import SwiftUI
import Supabase

struct CBTModuleDetailView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.cbtRepository) private var cbtRepo

    let module: Module
    let cbtViewModel: CBTViewModel

    var body: some View {
        let lessons = cbtViewModel.lessonsByModule[module.id] ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Module header
                Text(module.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                // Progress summary
                let completed = cbtViewModel.completedLessonCount(for: module.id)
                let total = cbtViewModel.totalLessonCount(for: module.id)

                HStack {
                    Label("\(completed)/\(total) completed", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(completed == total && total > 0 ? .green : .secondary)

                    Spacer()

                    Label("\(module.estimatedMinutes) min total", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                // Lessons
                VStack(spacing: 12) {
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                        let status = cbtViewModel.lessonStatus(lesson.id)

                        NavigationLink {
                            LessonView(lesson: lesson, cbtViewModel: cbtViewModel)
                        } label: {
                            LessonRow(lesson: lesson, index: index + 1, status: status)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                // Practice quiz button — questions for this module from the bundled bank
                let practiceQuestions = AppContent.questions(in: module.id)
                if !practiceQuestions.isEmpty {
                    NavigationLink {
                        QuizSessionView(
                            questions: practiceQuestions,
                            title: "\(module.title) Practice"
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.title3)
                                .foregroundStyle(.purple)
                                .frame(width: 40, height: 40)
                                .background(.purple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Practice Quiz")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(practiceQuestions.count) questions — multiple choice, swipe, matching")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .themedBackground()
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lesson Row

private struct LessonRow: View {
    let lesson: Lesson
    let index: Int
    let status: LessonProgressStatus

    var body: some View {
        CardView {
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(index)")
                            .font(.subheadline.bold())
                            .foregroundStyle(status == .inProgress ? .blue : .secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .completed: .green
        case .inProgress: .blue
        case .notStarted: .secondary
        }
    }
}
