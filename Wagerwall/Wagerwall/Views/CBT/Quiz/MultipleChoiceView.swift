import SwiftUI

struct MultipleChoiceView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var selectedIndex: Int? = nil

    var body: some View {
        // Extract type-specific payload up front; if mismatched, show a fallback.
        guard case .multipleChoice(let options, let correctIndex) = question.payload else {
            return AnyView(
                Text("Unsupported question type for MultipleChoiceView")
                    .foregroundStyle(.secondary)
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 20) {
                Text(question.prompt)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button {
                            guard selectedIndex == nil else { return }
                            selectedIndex = index
                            onAnswer(index == correctIndex)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(borderColor(index: index, correctIndex: correctIndex), lineWidth: 2)
                                        .frame(width: 28, height: 28)

                                    if selectedIndex != nil {
                                        if index == correctIndex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.green)
                                        } else if index == selectedIndex {
                                            Image(systemName: "xmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }

                                Text(option)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(16)
                            .background(backgroundColor(index: index, correctIndex: correctIndex))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(borderColor(index: index, correctIndex: correctIndex), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedIndex != nil)
                    }
                }

                if isShowingFeedback {
                    feedbackView(correctIndex: correctIndex)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
        )
    }

    @ViewBuilder
    private func feedbackView(correctIndex: Int) -> some View {
        let isCorrect = selectedIndex == correctIndex

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3)
                .foregroundStyle(isCorrect ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.subheadline.bold())
                    .foregroundStyle(isCorrect ? .green : .orange)

                Text(question.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? Color.green : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func borderColor(index: Int, correctIndex: Int) -> Color {
        guard let selected = selectedIndex else {
            return .secondary.opacity(0.3)
        }
        if index == correctIndex { return .green }
        if index == selected { return .red }
        return .secondary.opacity(0.3)
    }

    private func backgroundColor(index: Int, correctIndex: Int) -> Color {
        guard let selected = selectedIndex else {
            return .secondary.opacity(0.06)
        }
        if index == correctIndex { return .green.opacity(0.08) }
        if index == selected { return .red.opacity(0.08) }
        return .secondary.opacity(0.06)
    }
}
