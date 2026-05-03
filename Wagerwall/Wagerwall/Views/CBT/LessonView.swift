import SwiftUI
import Supabase

struct LessonView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.cbtRepository) private var cbtRepo
    @Environment(\.dismiss) private var dismiss

    let lesson: Lesson
    let cbtViewModel: CBTViewModel

    @State private var viewModel: LessonViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isCompleted {
                    LessonCompleteView(
                        lesson: lesson,
                        viewModel: viewModel
                    ) {
                        if let progress = viewModel.progress {
                            cbtViewModel.didCompleteLesson(progress)
                        }
                        dismiss()
                    }
                } else {
                    lessonContent(viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .themedBackground()
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await setupLesson() }
    }

    @ViewBuilder
    private func lessonContent(_ vm: LessonViewModel) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: vm.sectionProgress)
                .tint(.blue)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Section content
            ScrollView {
                if let section = vm.currentSection {
                    sectionView(for: section, at: vm.currentSectionIndex, vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .id(vm.currentSectionIndex)
                }
            }

            // Navigation buttons
            HStack(spacing: 12) {
                if vm.currentSectionIndex > 0 {
                    Button {
                        withAnimation { vm.goBack() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    withAnimation { vm.advance() }
                } label: {
                    HStack(spacing: 4) {
                        if vm.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(vm.isLastSection ? "Complete" : "Next")
                            if !vm.isLastSection {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(vm.canAdvance ? .blue : .blue.opacity(0.4))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!vm.canAdvance || vm.isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func sectionView(for section: LessonSection, at index: Int, vm: LessonViewModel) -> some View {
        switch section {
        case .text(let title, let body):
            TextSectionView(title: title, text: body)
        case .callout(let style, let body):
            CalloutSectionView(style: style, text: body)
        case .question(let questionId):
            if let question = AppContent.question(id: questionId) {
                inlineQuestionView(question, vm: vm)
            } else {
                Text("Missing question: \(questionId)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        case .journal(let prompt):
            JournalSectionView(
                prompt: prompt,
                text: Binding(
                    get: { vm.journalEntries[index] ?? "" },
                    set: { vm.journalEntries[index] = $0 }
                )
            )
        }
    }

    @ViewBuilder
    private func inlineQuestionView(_ question: Question, vm: LessonViewModel) -> some View {
        let isAnswered = vm.questionResults[question.id] != nil
        let onAnswer: (Bool) -> Void = { isCorrect in
            vm.recordAnswer(questionId: question.id, isCorrect: isCorrect)
        }

        switch question.payload {
        case .multipleChoice:
            MultipleChoiceView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .trueFalse:
            TrueFalseView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .matching:
            MatchingView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .multipleSelect:
            MultipleSelectView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .fillInBlank:
            FillInBlankView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .sortOrder:
            SortOrderView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        case .swipeCategorize:
            SwipeCategorizeView(
                question: question,
                isShowingFeedback: isAnswered,
                onAnswer: onAnswer
            )
        }
    }

    private func setupLesson() async {
        guard let userId = auth.currentUserId else { return }
        let vm = LessonViewModel(lesson: lesson, userId: userId, cbtRepo: cbtRepo)
        viewModel = vm
        await vm.markStarted()
    }
}

// MARK: - Text Section

struct TextSectionView: View {
    let title: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title3.bold())
            }

            Text(LocalizedStringKey(text))
                .font(.body)
                .lineSpacing(4)
        }
    }
}

// MARK: - Callout Section

struct CalloutSectionView: View {
    let style: CalloutStyle
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: calloutIcon)
                .font(.title3)
                .foregroundStyle(calloutColor)
                .frame(width: 24)

            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(calloutColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var calloutIcon: String {
        switch style {
        case .tip: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .example: "text.quote"
        case .reflection: "bubble.left.and.text.bubble.right.fill"
        }
    }

    private var calloutColor: Color {
        switch style {
        case .tip: .blue
        case .warning: .orange
        case .example: .purple
        case .reflection: .teal
        }
    }
}

// MARK: - Journal Section

struct JournalSectionView: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.teal)
                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Write your thoughts...", text: $text, axis: .vertical)
                .lineLimit(5...12)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .background(.teal.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
