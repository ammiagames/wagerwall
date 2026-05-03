import SwiftUI

struct LessonCompleteView: View {
    let lesson: Lesson
    let viewModel: LessonViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Celebration
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Lesson Complete!")
                    .font(.title.bold())

                Text(lesson.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats — prefer ViewModel state (works even when persistence failed)
            VStack(spacing: 12) {
                if viewModel.totalQuestions > 0 {
                    StatRow(
                        icon: "checkmark.circle",
                        label: "Quiz Score",
                        value: "\(viewModel.correctAnswerCount)/\(viewModel.totalQuestions)"
                    )
                }

                let journalCount = viewModel.journalEntries.values
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .count
                if journalCount > 0 {
                    StatRow(icon: "note.text", label: "Journal Entries", value: "\(journalCount)")
                }

                StatRow(icon: "clock", label: "Estimated Time", value: "\(lesson.estimatedMinutes) min")
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            WagerWallButton(title: "Continue", action: onDismiss)
                .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }
}
