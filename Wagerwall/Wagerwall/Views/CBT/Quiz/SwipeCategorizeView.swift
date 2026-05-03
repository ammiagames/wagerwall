import SwiftUI

/// Renders a `Question.Payload.swipeCategorize`. Cards are presented in a
/// stack; the user swipes (or taps the side buttons) to assign each card to
/// the left or right category. After every card is sorted, results are
/// shown — the question is correct only if every card landed on the right
/// side, mirroring how matching scores: all-or-nothing for the streak.
struct SwipeCategorizeView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var currentIndex: Int = 0
    @State private var offset: CGSize = .zero
    @State private var results: [Question.SwipeSide] = []
    @State private var hasReported = false

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        guard case .swipeCategorize(let leftLabel, let rightLabel, let cards) = question.payload else {
            return AnyView(
                Text("Unsupported payload for SwipeCategorizeView")
                    .foregroundStyle(.secondary)
            )
        }
        return AnyView(content(leftLabel: leftLabel, rightLabel: rightLabel, cards: cards))
    }

    private func content(leftLabel: String, rightLabel: String, cards: [Question.SwipeCard]) -> some View {
        let isFinished = currentIndex >= cards.count

        return VStack(spacing: 16) {
            QuestionPromptHeader(prompt: question.prompt)

            categoryHeaders(leftLabel: leftLabel, rightLabel: rightLabel)

            if !isFinished {
                cardStack(cards: cards, leftLabel: leftLabel, rightLabel: rightLabel)
                    .frame(height: 220)

                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                sideButtons(leftLabel: leftLabel, rightLabel: rightLabel, cards: cards)
            } else {
                resultsList(cards: cards, leftLabel: leftLabel, rightLabel: rightLabel)
                    .onAppear {
                        guard !hasReported else { return }
                        hasReported = true
                        let allCorrect = zip(results, cards).allSatisfy { $0 == $1.correctSide }
                        triggerHaptic(allCorrect: allCorrect)
                        onAnswer(allCorrect)
                    }
            }

            if isShowingFeedback {
                let allCorrect = results.count == cards.count
                    && zip(results, cards).allSatisfy { $0 == $1.correctSide }
                QuestionFeedbackCard(
                    isCorrect: allCorrect,
                    explanation: question.explanation
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
    }

    // MARK: - Subviews

    private func categoryHeaders(leftLabel: String, rightLabel: String) -> some View {
        HStack {
            categoryPill(text: leftLabel, alignment: .leading, color: .red)
            Spacer()
            categoryPill(text: rightLabel, alignment: .trailing, color: .green)
        }
    }

    private func categoryPill(text: String, alignment: HorizontalAlignment, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.85))
            .clipShape(Capsule())
    }

    private func cardStack(cards: [Question.SwipeCard], leftLabel: String, rightLabel: String) -> some View {
        ZStack {
            // Render up to two cards behind the top one for stack visual.
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                if index == currentIndex {
                    topCard(card: card, leftLabel: leftLabel, rightLabel: rightLabel)
                        .zIndex(2)
                        .transition(.identity)
                } else if index == currentIndex + 1 {
                    backCard(card: card, depth: 1)
                        .zIndex(1)
                } else if index == currentIndex + 2 {
                    backCard(card: card, depth: 2)
                        .zIndex(0)
                }
            }
        }
    }

    private func topCard(card: Question.SwipeCard, leftLabel: String, rightLabel: String) -> some View {
        let dragX = offset.width
        let leftIntensity = dragX < 0 ? min(-Double(dragX) / Double(swipeThreshold), 1.0) : 0
        let rightIntensity = dragX > 0 ? min(Double(dragX) / Double(swipeThreshold), 1.0) : 0

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(QuizPalette.idleBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(QuizPalette.idleBorder, lineWidth: 2)
                )
                .overlay(
                    // Color overlay tint based on drag direction
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.green.opacity(0.18 * rightIntensity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.red.opacity(0.18 * leftIntensity))
                )

            VStack(spacing: 14) {
                Text(card.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(QuizPalette.idleText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                if dragX > 30 {
                    Text(rightLabel.uppercased())
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.green)
                        .opacity(rightIntensity)
                } else if dragX < -30 {
                    Text(leftLabel.uppercased())
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.red)
                        .opacity(leftIntensity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(offset.width) / 22))
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    handleDragEnd(translation: value.translation.width)
                }
        )
    }

    private func backCard(card: Question.SwipeCard, depth: Int) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(QuizPalette.idleBg)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(QuizPalette.idleBorder, lineWidth: 2)
            )
            .overlay(
                Text(card.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(QuizPalette.idleText.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.0 - 0.05 * Double(depth))
            .offset(y: 8 * Double(depth))
            .opacity(1.0 - 0.25 * Double(depth))
    }

    private func sideButtons(leftLabel: String, rightLabel: String, cards: [Question.SwipeCard]) -> some View {
        HStack(spacing: 12) {
            sideButton(label: leftLabel, side: .left, color: .red, systemImage: "arrow.left") {
                commit(side: .left, cards: cards)
            }
            sideButton(label: rightLabel, side: .right, color: .green, systemImage: "arrow.right") {
                commit(side: .right, cards: cards)
            }
        }
    }

    private func sideButton(label: String, side: Question.SwipeSide, color: Color, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if side == .left {
                    Image(systemName: systemImage)
                }
                Text(label)
                    .lineLimit(1)
                if side == .right {
                    Image(systemName: systemImage)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func resultsList(cards: [Question.SwipeCard], leftLabel: String, rightLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your sort")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    let userPick = results.indices.contains(index) ? results[index] : .left
                    let isCorrect = userPick == card.correctSide
                    let pickLabel = userPick == .left ? leftLabel : rightLabel

                    HStack(spacing: 10) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isCorrect ? .green : .red)
                        Text(card.text)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isCorrect ? QuizPalette.correctText : QuizPalette.wrongText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(pickLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isCorrect ? .green : .red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isCorrect ? QuizPalette.correctBg : QuizPalette.wrongBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCorrect ? QuizPalette.correctBorder : QuizPalette.wrongBorder, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Drag handling

    private func handleDragEnd(translation: CGFloat) {
        guard case .swipeCategorize(_, _, let cards) = question.payload else { return }

        if translation > swipeThreshold {
            withAnimation(.easeOut(duration: 0.2)) { offset = CGSize(width: 600, height: 0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                commit(side: .right, cards: cards)
            }
        } else if translation < -swipeThreshold {
            withAnimation(.easeOut(duration: 0.2)) { offset = CGSize(width: -600, height: 0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                commit(side: .left, cards: cards)
            }
        } else {
            withAnimation(.spring(response: 0.3)) { offset = .zero }
        }
    }

    private func commit(side: Question.SwipeSide, cards: [Question.SwipeCard]) {
        guard currentIndex < cards.count else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        results.append(side)
        currentIndex += 1
        offset = .zero
    }

    private func triggerHaptic(allCorrect: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(allCorrect ? .success : .error)
    }
}
