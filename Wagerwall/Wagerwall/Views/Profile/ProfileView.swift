import SwiftUI
import Supabase

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo
    @Environment(\.streakRepository) private var streakRepo

    @State private var profile: UserProfile?
    @State private var stats: StreakStats?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                identityHeader
                streakHero
                statsRow
                navSection(title: "Recovery") {
                    navRow(
                        icon: "brain.head.profile",
                        iconBg: .indigo,
                        title: "PGSI Assessment",
                        trailing: profile?.gamblingSeverity?.rawValue.capitalized ?? "Not taken"
                    ) {
                        AssessmentView()
                    }
                    Divider().background(.white.opacity(0.06))
                    navRow(
                        icon: "person.2.fill",
                        iconBg: .purple,
                        title: "Accountability Partners"
                    ) {
                        AccountabilityPartnersView()
                    }
                }
                navSection(title: "Account") {
                    navRow(icon: "pencil", iconBg: .blue, title: "Edit Profile") {
                        EditProfileView(profile: profile)
                    }
                    Divider().background(.white.opacity(0.06))
                    navRow(icon: "gearshape.fill", iconBg: .gray, title: "App Settings") {
                        SettingsView()
                    }
                    Divider().background(.white.opacity(0.06))
                    navRow(
                        icon: "phone.arrow.up.right.fill",
                        iconBg: .red,
                        title: "Crisis Resources"
                    ) {
                        CrisisResourcesView()
                    }
                }
                signOutButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Identity Header

    @ViewBuilder
    private var identityHeader: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName?.nilIfEmpty ?? "Welcome")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let email = auth.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var avatar: some View {
        let size: CGFloat = 56
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.heroStart, Theme.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))

            if let url = profile?.avatarUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarInitials
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarInitials
            }
        }
    }

    private var avatarInitials: some View {
        Text(initials)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }

    private var initials: String {
        let source = profile?.displayName?.nilIfEmpty ?? auth.userEmail ?? "?"
        let parts = source.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first.map(String.init) }.joined()
        return chars.isEmpty ? String(source.prefix(1)).uppercased() : chars.uppercased()
    }

    // MARK: - Streak Hero

    @ViewBuilder
    private var streakHero: some View {
        let days = stats?.currentStreakDays ?? 0
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                Text("Current Streak")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(days)")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(days)))
                Text(days == 1 ? "day" : "days")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(motivationalLine)
                .font(.footnote)
                .foregroundStyle(Theme.tabActive)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.heroStart, Theme.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var motivationalLine: String {
        guard let stats else { return "Every day counts." }
        if stats.currentStreakDays == 0 {
            return "Tap the dashboard to check in and start a new streak."
        }
        if stats.currentStreakDays == stats.longestStreakDays && stats.totalStreaks > 1 {
            return "You're at your personal best. Keep going."
        }
        if stats.longestStreakDays > stats.currentStreakDays {
            let togo = stats.longestStreakDays - stats.currentStreakDays
            return "\(togo) day\(togo == 1 ? "" : "s") to beat your record."
        }
        return "Every day counts."
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        let s = stats ?? .empty
        HStack(spacing: 12) {
            metricCard(
                icon: "trophy.fill",
                iconColor: .yellow,
                label: "Longest",
                value: s.longestStreakDays > 0 ? "\(s.longestStreakDays)" : "—",
                unit: s.longestStreakDays > 0 ? (s.longestStreakDays == 1 ? "day" : "days") : nil
            )
            metricCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .green,
                label: "Average",
                value: averageDisplay(s),
                unit: s.totalStreaks > 0 ? "days" : nil
            )
            metricCard(
                icon: "rosette",
                iconColor: Theme.tabActive,
                label: percentileLabel(s),
                value: percentileValue(s),
                unit: s.totalUsers > 1 ? "of users" : nil
            )
        }
    }

    private func averageDisplay(_ s: StreakStats) -> String {
        guard s.totalStreaks > 0 else { return "—" }
        return s.averageStreakDays.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func percentileLabel(_ s: StreakStats) -> String {
        if s.totalUsers <= 1 || s.currentStreakDays == 0 { return "Rank" }
        return "Top"
    }

    private func percentileValue(_ s: StreakStats) -> String {
        guard s.totalUsers > 1, s.currentStreakDays > 0 else { return "—" }
        let topPct = max(1.0, 100.0 - s.percentile)
        // Round up so a 99.x percentile shows as "Top 1%" not "Top 0%"
        let display = topPct < 1 ? 1 : Int(topPct.rounded())
        return "\(display)%"
    }

    @ViewBuilder
    private func metricCard(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        unit: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))

                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
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

    // MARK: - Nav Sections

    @ViewBuilder
    private func navSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
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
    }

    @ViewBuilder
    private func navRow<Destination: View>(
        icon: String,
        iconBg: Color,
        title: String,
        trailing: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBg.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconBg)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sign Out

    @ViewBuilder
    private var signOutButton: some View {
        Button(role: .destructive) {
            Task { await auth.signOut() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sign Out")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.red.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.red.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private func load() async {
        guard let userId = auth.currentUserId else {
            isLoading = false
            return
        }
        async let profileResult = try? await profileRepo.fetchProfile(userId: userId)
        async let statsResult = try? await streakRepo.fetchStats(userId: userId)
        let (loadedProfile, loadedStats) = await (profileResult, statsResult)
        profile = loadedProfile
        stats = loadedStats ?? .empty
        isLoading = false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
