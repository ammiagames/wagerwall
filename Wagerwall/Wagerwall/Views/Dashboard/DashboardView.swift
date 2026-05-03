import SwiftUI
import Supabase

struct DashboardView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo
    @Environment(\.streakRepository) private var streakRepo
    @Environment(\.moodLogRepository) private var moodRepo
    @Environment(\.urgeLogRepository) private var urgeRepo

    @State private var viewModel: DashboardViewModel?
    @State private var showLogMood = false
    @State private var showLogUrge = false
    @State private var showPanicButton = false

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading {
                dashboardContent(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadDashboard() }
        .refreshable { await refreshDashboard() }
        .sheet(isPresented: $showLogMood) {
            LogMoodView { mood in
                viewModel?.didLogMood(mood)
            }
        }
        .sheet(isPresented: $showLogUrge) {
            LogUrgeView { urge in
                viewModel?.didLogUrge(urge)
            }
        }
        .fullScreenCover(isPresented: $showPanicButton) {
            PanicButtonView()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func dashboardContent(_ vm: DashboardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                welcomeHeader(vm)
                heroCard(vm)
                savingsBanner(vm)
                dailyCheckInRow(vm)
                reminderCard
                panicButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Welcome Header

    @ViewBuilder
    private func welcomeHeader(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.greeting)
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("You're building new patterns")
                .font(.subheadline)
                .foregroundStyle(Theme.tabActive)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Hero Card (Protection Status + Streak)

    @ViewBuilder
    private func heroCard(_ vm: DashboardViewModel) -> some View {
        VStack(spacing: 20) {
            // Shield icon
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.tabActive)
                .shadow(color: Theme.tabActive.opacity(0.35), radius: 24)

            // Status
            VStack(spacing: 4) {
                Text("Protection Status")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Active")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .underline()
            }

            // Days counter
            VStack(spacing: 2) {
                Text("\(vm.streakDays)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Days Protected")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Motivational message
            Text(vm.streakMessage)
                .font(.footnote)
                .foregroundStyle(Theme.tabActive)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.heroStart, Theme.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Savings Card

    @ViewBuilder
    private func savingsBanner(_ vm: DashboardViewModel) -> some View {
        HStack(spacing: 16) {
            // Icon in green circle
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Money Saved")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("$\(Int(vm.estimatedSavings))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if vm.dailySpend > 0 {
                        Text("$\(Int(vm.dailySpend))/day")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.cardStart, Theme.cardEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Daily Check-in Row

    @ViewBuilder
    private func dailyCheckInRow(_ vm: DashboardViewModel) -> some View {
        HStack(spacing: 12) {
            // Mood
            Button { showLogMood = true } label: {
                actionTile(
                    icon: {
                        if let mood = vm.todaysMood {
                            let face = MoodLogViewModel.moodFaces.first { $0.score == mood.moodScore }
                            return AnyView(
                                Text(face?.emoji ?? "😐")
                                    .font(.system(size: 24))
                            )
                        } else {
                            return AnyView(
                                Image(systemName: "face.smiling.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            )
                        }
                    },
                    iconBg: .blue,
                    title: vm.todaysMood != nil
                        ? (MoodLogViewModel.moodFaces.first { $0.score == vm.todaysMood!.moodScore }?.label ?? "Logged")
                        : "Check in",
                    subtitle: "Mood"
                )
            }
            .buttonStyle(.plain)

            // Urges
            Button { showLogUrge = true } label: {
                actionTile(
                    icon: {
                        AnyView(
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        )
                    },
                    iconBg: .orange,
                    title: "\(vm.todaysUrgeCount)",
                    subtitle: "Urges"
                )
            }
            .buttonStyle(.plain)

            // SOS
            Button { showPanicButton = true } label: {
                actionTile(
                    icon: {
                        AnyView(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        )
                    },
                    iconBg: .red,
                    title: "SOS",
                    subtitle: "Panic"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionTile(
        icon: () -> AnyView,
        iconBg: Color,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBg.opacity(0.2))
                    .frame(width: 44, height: 44)
                icon()
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Theme.cardStart, Theme.cardEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Daily Reminder

    private var reminderCard: some View {
        let quote = DashboardViewModel.dailyQuote
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.tabActive.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.tabActive)
                }
                Text("Today's Reminder")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(quote.text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(quote.author)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.cardStart, Theme.cardEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Panic Button

    private var panicButton: some View {
        Button { showPanicButton = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sos.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Panic Button")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Feeling an urge? Tap for immediate help")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.75, green: 0.15, blue: 0.15),
                        Color(red: 0.90, green: 0.40, blue: 0.15)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadDashboard() async {
        guard let userId = auth.currentUserId else { return }
        let vm = DashboardViewModel(
            profileRepo: profileRepo,
            streakRepo: streakRepo,
            moodRepo: moodRepo,
            urgeRepo: urgeRepo
        )
        viewModel = vm
        await vm.load(userId: userId)
    }

    private func refreshDashboard() async {
        guard let userId = auth.currentUserId else { return }
        await viewModel?.refresh(userId: userId)
    }
}
