import SwiftUI

struct QuizSessionView: View {
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: QuizSessionViewModel

    init(questions: [Question], title: String) {
        _viewModel = State(initialValue: QuizSessionViewModel(questions: questions, title: title))
    }

    var body: some View {
        Group {
            if viewModel.isComplete {
                QuizCompleteView(viewModel: viewModel) {
                    dismiss()
                }
            } else {
                quizContent
            }
        }
        .themedBackground()
    }

    // MARK: - Quiz Content

    private var quizContent: some View {
        VStack(spacing: 0) {
            // Header: progress bar + streak
            VStack(spacing: 8) {
                ProgressView(value: viewModel.progress)
                    .tint(.blue)

                HStack {
                    Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if viewModel.streak > 1 {
                        Label("\(viewModel.streak) streak", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Question content
            ScrollView {
                if let question = viewModel.currentQuestion {
                    questionView(for: question)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        .id(viewModel.currentIndex)
                }
            }

            // Continue button (shown after answering)
            if viewModel.isShowingFeedback {
                continueButton
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Exit") { dismiss() }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isShowingFeedback)
    }

    // MARK: - Question Router

    @ViewBuilder
    private func questionView(for question: Question) -> some View {
        let onAnswer: (Bool) -> Void = { isCorrect in
            viewModel.submitAnswer(isCorrect: isCorrect)
        }

        switch question.payload {
        case .multipleChoice:
            MultipleChoiceView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .trueFalse:
            TrueFalseView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .matching:
            MatchingView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .multipleSelect:
            MultipleSelectView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .fillInBlank:
            FillInBlankView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .sortOrder:
            SortOrderView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )

        case .swipeCategorize:
            SwipeCategorizeView(
                question: question,
                isShowingFeedback: viewModel.isShowingFeedback,
                onAnswer: onAnswer
            )
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            withAnimation { viewModel.continueToNext() }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.questionsRemaining <= 1 ? "See Results" : "Continue")
                Image(systemName: "arrow.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.lastAnswerCorrect == true ? .green : .blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
