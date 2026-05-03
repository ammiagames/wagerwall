import SwiftUI

/// Renders a `Question.Payload.trueFalse`. The user can either swipe the
/// card (right = True, left = False) or tap the accessibility buttons.
/// The struct was originally named `SwipeCardView`; renamed to
/// `TrueFalseView` once `SwipeCategorizeView` joined the family, since
/// that's the actual swipe-to-categorize renderer.
struct TrueFalseView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var hasAnswered = false
    @State private var userSaidTrue: Bool? = nil

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        guard case .trueFalse(let correctAnswer) = question.payload else {
            return AnyView(
                Text("Unsupported question type for SwipeCardView")
                    .foregroundStyle(.secondary)
            )
        }
        return AnyView(swipeCard(correctAnswer: correctAnswer))
    }

    private func swipeCard(correctAnswer: Bool) -> some View {

        VStack(spacing: 24) {
            Text(question.prompt)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            if !hasAnswered {
                activeCard
            } else {
                answeredCard(correctAnswer: correctAnswer)
            }

            if isShowingFeedback {
                feedbackView(correctAnswer: correctAnswer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
        .animation(.easeInOut(duration: 0.3), value: hasAnswered)
    }

    // MARK: - Active Card (draggable)

    private var activeCard: some View {
        VStack(spacing: 20) {
            // Swipeable card
            ZStack {
                // FALSE label (left)
                Text("FALSE")
                    .font(.title.bold())
                    .foregroundStyle(.red)
                    .opacity(falseOpacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)

                // TRUE label (right)
                Text("TRUE")
                    .font(.title.bold())
                    .foregroundStyle(.green)
                    .opacity(trueOpacity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 24)

                // The card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardBorderColor, lineWidth: 3)
                    )
                    .frame(height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "hand.draw")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Swipe to answer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    )
                    .offset(x: offset.width)
                    .rotationEffect(.degrees(Double(offset.width) / 20))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                            }
                            .onEnded { value in
                                handleSwipeEnd(translation: value.translation.width)
                            }
                    )
            }

            // Accessibility fallback buttons
            HStack(spacing: 16) {
                Button {
                    submitAnswer(userSaysTrue: false)
                } label: {
                    Label("False", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    submitAnswer(userSaysTrue: true)
                } label: {
                    Label("True", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Answered state

    @ViewBuilder
    private func answeredCard(correctAnswer: Bool) -> some View {
        let isCorrect = userSaidTrue == correctAnswer

        HStack(spacing: 16) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(isCorrect ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text("You answered: \(userSaidTrue == true ? "True" : "False")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Correct answer: \(correctAnswer ? "True" : "False")")
                    .font(.subheadline.bold())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? Color.green : Color.red).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Feedback

    @ViewBuilder
    private func feedbackView(correctAnswer: Bool) -> some View {
        let isCorrect = userSaidTrue == correctAnswer

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3)
                .foregroundStyle(isCorrect ? .green : .orange)

            Text(question.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? Color.green : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Gesture Handling

    private func handleSwipeEnd(translation: CGFloat) {
        if translation > swipeThreshold {
            // Swiped right → TRUE
            withAnimation(.easeOut(duration: 0.2)) {
                offset = CGSize(width: 500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                submitAnswer(userSaysTrue: true)
            }
        } else if translation < -swipeThreshold {
            // Swiped left → FALSE
            withAnimation(.easeOut(duration: 0.2)) {
                offset = CGSize(width: -500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                submitAnswer(userSaysTrue: false)
            }
        } else {
            // Snap back
            withAnimation(.spring(response: 0.3)) {
                offset = .zero
            }
        }
    }

    private func submitAnswer(userSaysTrue: Bool) {
        guard !hasAnswered else { return }
        guard case .trueFalse(let correct) = question.payload else { return }
        userSaidTrue = userSaysTrue
        hasAnswered = true
        offset = .zero
        onAnswer(userSaysTrue == correct)
    }

    // MARK: - Visual feedback during drag

    private var trueOpacity: Double {
        guard offset.width > 0 else { return 0 }
        return min(Double(offset.width) / Double(swipeThreshold), 1.0)
    }

    private var falseOpacity: Double {
        guard offset.width < 0 else { return 0 }
        return min(Double(-offset.width) / Double(swipeThreshold), 1.0)
    }

    private var cardBorderColor: Color {
        if offset.width > swipeThreshold / 2 { return .green.opacity(0.6) }
        if offset.width < -swipeThreshold / 2 { return .red.opacity(0.6) }
        return .clear
    }
}
