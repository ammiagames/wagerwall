import SwiftUI
import Supabase

struct LogMoodView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.moodLogRepository) private var moodRepo
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = MoodLogViewModel()
    var onLogged: ((MoodLog) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text("How are you feeling?")
                    .font(.title2.bold())

                // Mood faces
                HStack(spacing: 16) {
                    ForEach(MoodLogViewModel.moodFaces, id: \.score) { face in
                        Button {
                            viewModel.moodScore = face.score
                        } label: {
                            VStack(spacing: 6) {
                                Text(face.emoji)
                                    .font(.system(size: 40))
                                    .scaleEffect(viewModel.moodScore == face.score ? 1.2 : 1.0)

                                Text(face.label)
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.moodScore == face.score ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.moodScore)
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("How's your day going?", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 24)

                Spacer()

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                WagerWallButton(
                    title: "Log Mood",
                    isLoading: viewModel.isSaving
                ) {
                    Task {
                        guard let userId = auth.currentUserId else { return }
                        if let log = await viewModel.save(userId: userId, repo: moodRepo) {
                            onLogged?(log)
                            dismiss()
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Log Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
