import SwiftUI

struct QuizCompleteView: View {
    let viewModel: QuizSessionViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Score circle
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: Double(viewModel.scorePercent) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(viewModel.scorePercent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("\(viewModel.correctCount)/\(viewModel.totalAnswered)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Title + message
            VStack(spacing: 8) {
                Text(titleText)
                    .font(.title2.bold())

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Stats grid
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    statBox(
                        icon: "checkmark.circle",
                        value: "\(viewModel.correctCount)",
                        label: "Correct",
                        color: .green
                    )

                    statBox(
                        icon: "xmark.circle",
                        value: "\(viewModel.totalAnswered - viewModel.correctCount)",
                        label: "Incorrect",
                        color: .red
                    )
                }

                HStack(spacing: 16) {
                    statBox(
                        icon: "flame.fill",
                        value: "\(viewModel.bestStreak)",
                        label: "Best Streak",
                        color: .orange
                    )

                    statBox(
                        icon: "number",
                        value: "\(viewModel.totalAnswered)",
                        label: "Questions",
                        color: .blue
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            WagerWallButton(title: "Done", action: onDismiss)
                .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        let pct = viewModel.scorePercent
        if pct >= 80 { return .green }
        if pct >= 50 { return .orange }
        return .red
    }

    private var titleText: String {
        let pct = viewModel.scorePercent
        if pct == 100 { return "Perfect Score!" }
        if pct >= 80 { return "Great Job!" }
        if pct >= 50 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    private var subtitleText: String {
        let pct = viewModel.scorePercent
        if pct >= 80 { return "You have a strong understanding of these concepts." }
        if pct >= 50 { return "You're getting there. Review the lessons and try again." }
        return "Review the lessons and come back to try again."
    }

    @ViewBuilder
    private func statBox(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
