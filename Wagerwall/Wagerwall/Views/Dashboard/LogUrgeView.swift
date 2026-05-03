import SwiftUI
import Supabase

struct LogUrgeView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.urgeLogRepository) private var urgeRepo
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = UrgeLogViewModel()
    var onLogged: ((UrgeLog) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Intensity
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Intensity")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.intensity))/10")
                                .font(.title2.bold())
                                .foregroundStyle(intensityColor)
                        }

                        Slider(value: $viewModel.intensity, in: 1...10, step: 1)
                            .tint(intensityColor)

                        HStack {
                            Text("Mild")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Severe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Trigger
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What triggered this urge?")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(UrgeLogViewModel.triggerCategories, id: \.self) { trigger in
                                TriggerChip(
                                    label: trigger,
                                    isSelected: viewModel.triggerCategory == trigger,
                                    action: {
                                        viewModel.triggerCategory = viewModel.triggerCategory == trigger ? "" : trigger
                                    }
                                )
                            }
                        }

                        TextField("Additional notes...", text: $viewModel.triggerNotes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Outcome
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Outcome")
                            .font(.headline)

                        ForEach(UrgeOutcome.allCases, id: \.self) { outcome in
                            Button {
                                viewModel.outcome = outcome
                            } label: {
                                HStack {
                                    Image(systemName: outcomeIcon(outcome))
                                        .foregroundStyle(outcomeColor(outcome))
                                    Text(outcomeLabel(outcome))
                                    Spacer()
                                    if viewModel.outcome == outcome {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(12)
                                .background(viewModel.outcome == outcome ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Coping strategy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coping strategy used (optional)")
                            .font(.headline)

                        TextField("e.g. deep breathing, called a friend...", text: $viewModel.copingStrategy, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            WagerWallButton(
                title: "Log Urge",
                isLoading: viewModel.isSaving
            ) {
                Task {
                    guard let userId = auth.currentUserId else { return }
                    if let log = await viewModel.save(userId: userId, repo: urgeRepo) {
                        onLogged?(log)
                        dismiss()
                    }
                }
            }
            .padding(.bottom, 16)
            .navigationTitle("Log Urge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var intensityColor: Color {
        switch Int(viewModel.intensity) {
        case 1...3: .green
        case 4...6: .orange
        default: .red
        }
    }

    private func outcomeIcon(_ outcome: UrgeOutcome) -> String {
        switch outcome {
        case .resisted: "hand.thumbsup.fill"
        case .gaveIn: "exclamationmark.triangle.fill"
        case .usedPanicButton: "sos.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: UrgeOutcome) -> Color {
        switch outcome {
        case .resisted: .green
        case .gaveIn: .red
        case .usedPanicButton: .orange
        }
    }

    private func outcomeLabel(_ outcome: UrgeOutcome) -> String {
        switch outcome {
        case .resisted: "I resisted"
        case .gaveIn: "I gave in"
        case .usedPanicButton: "Used panic button"
        }
    }
}

// MARK: - Supporting Views

private struct TriggerChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .blue : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
