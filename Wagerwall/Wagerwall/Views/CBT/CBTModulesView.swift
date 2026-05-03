import SwiftUI
import Supabase

struct CBTModulesView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.cbtRepository) private var cbtRepo

    @State private var viewModel: CBTViewModel?

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading {
                if viewModel.modules.isEmpty {
                    ContentUnavailableView(
                        "No Modules Yet",
                        systemImage: "book.closed",
                        description: Text("CBT modules are being prepared. Check back soon.")
                    )
                } else {
                    modulesContent(viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Learn")
        .task { await loadModules() }
        .refreshable { await refreshModules() }
    }

    @ViewBuilder
    private func modulesContent(_ vm: CBTViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(vm.modules) { module in
                    NavigationLink {
                        CBTModuleDetailView(module: module, cbtViewModel: vm)
                    } label: {
                        ModuleCard(module: module, vm: vm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func loadModules() async {
        guard let userId = auth.currentUserId else { return }
        let vm = CBTViewModel(cbtRepo: cbtRepo)
        viewModel = vm
        await vm.load(userId: userId)
    }

    private func refreshModules() async {
        guard let userId = auth.currentUserId else { return }
        await viewModel?.refresh(userId: userId)
    }
}

// MARK: - Module Card

private struct ModuleCard: View {
    let module: Module
    let vm: CBTViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: module.iconName)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(module.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }

                // Progress bar
                let completed = vm.completedLessonCount(for: module.id)
                let total = vm.totalLessonCount(for: module.id)
                let progressValue = vm.progress(for: module.id)

                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progressValue)
                        .tint(vm.isModuleCompleted(module.id) ? .green : .blue)

                    HStack {
                        Text("\(completed)/\(total) lessons")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Label("\(module.estimatedMinutes) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
