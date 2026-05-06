import SwiftUI

struct CBTModulesView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.cbtRepository) private var cbtRepo
    @Environment(\.streakRepository) private var streakRepo

    @State private var viewModel: CBTViewModel?
    @State private var streakDays: Int = 0

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
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadAll() }
        .refreshable { await refreshAll() }
    }

    @ViewBuilder
    private func modulesContent(_ vm: CBTViewModel) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                LearnHeader(subtitle: subtitle(for: vm))
                    .padding(.top, 8)

                if let target = resumeTarget(vm: vm) {
                    NavigationLink {
                        LessonView(lesson: target.lesson, cbtViewModel: vm)
                    } label: {
                        HeroCard(
                            target: target,
                            gradient: Self.gradient(for: target.module)
                        )
                    }
                    .buttonStyle(.plain)
                }

                StatsPill(
                    lessonsDone: completedTotal(vm: vm),
                    minutesDone: minutesDone(vm: vm),
                    streakDays: streakDays
                )

                VStack(spacing: 14) {
                    ForEach(vm.modules) { module in
                        NavigationLink {
                            CBTModuleDetailView(module: module, cbtViewModel: vm)
                        } label: {
                            ModuleCoverCard(
                                module: module,
                                lessonCount: vm.totalLessonCount(for: module.id),
                                completedCount: vm.completedLessonCount(for: module.id),
                                gradient: Self.gradient(for: module)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Loading

    private func loadAll() async {
        guard let userId = auth.currentUserId else { return }
        let vm = CBTViewModel(cbtRepo: cbtRepo)
        viewModel = vm
        await vm.load(userId: userId)
        if let s = try? await streakRepo.fetchStreak(userId: userId) {
            streakDays = s.currentStreakDays
        }
    }

    private func refreshAll() async {
        guard let userId = auth.currentUserId, let vm = viewModel else { return }
        await vm.refresh(userId: userId)
        if let s = try? await streakRepo.fetchStreak(userId: userId) {
            streakDays = s.currentStreakDays
        }
    }

    // MARK: - Derived

    private func completedTotal(vm: CBTViewModel) -> Int {
        vm.allProgress.filter { $0.status == .completed }.count
    }

    private func minutesDone(vm: CBTViewModel) -> Int {
        let completedIds = Set(vm.allProgress.filter { $0.status == .completed }.map(\.lessonId))
        return vm.modules
            .flatMap { vm.lessonsByModule[$0.id] ?? [] }
            .filter { completedIds.contains($0.id) }
            .map(\.estimatedMinutes)
            .reduce(0, +)
    }

    private func subtitle(for vm: CBTViewModel) -> String {
        let done = completedTotal(vm: vm)
        let total = vm.modules.reduce(0) { $0 + vm.totalLessonCount(for: $1.id) }
        if total == 0 { return "Your CBT journey" }
        if done == 0 { return "Your CBT journey starts here" }
        if done >= total { return "You've completed every lesson" }
        return "\(done) of \(total) lessons complete"
    }

    private func resumeTarget(vm: CBTViewModel) -> ResumeTarget? {
        let allLessons: [Lesson] = vm.modules.flatMap { vm.lessonsByModule[$0.id] ?? [] }
        guard !allLessons.isEmpty else { return nil }

        let inProgress = vm.allProgress.filter { $0.status == .inProgress }
        if let mostRecent = inProgress.max(by: {
            ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast)
        }),
           let lesson = allLessons.first(where: { $0.id == mostRecent.lessonId }),
           let module = vm.modules.first(where: { $0.id == lesson.moduleId }) {
            return ResumeTarget(
                lesson: lesson,
                module: module,
                eyebrow: "PICK UP WHERE YOU LEFT",
                ctaLabel: "Resume"
            )
        }

        let completedIds = Set(vm.allProgress.filter { $0.status == .completed }.map(\.lessonId))
        if let nextLesson = allLessons.first(where: { !completedIds.contains($0.id) }),
           let module = vm.modules.first(where: { $0.id == nextLesson.moduleId }) {
            let isFirstEver = vm.allProgress.isEmpty
            return ResumeTarget(
                lesson: nextLesson,
                module: module,
                eyebrow: isFirstEver ? "START YOUR JOURNEY" : "UP NEXT",
                ctaLabel: isFirstEver ? "Begin" : "Continue"
            )
        }

        if let firstLesson = allLessons.first,
           let module = vm.modules.first(where: { $0.id == firstLesson.moduleId }) {
            return ResumeTarget(
                lesson: firstLesson,
                module: module,
                eyebrow: "REVIEW",
                ctaLabel: "Revisit"
            )
        }

        return nil
    }

    // MARK: - Per-module gradient palette

    private static let gradientPalette: [[Color]] = [
        // 1: Understanding — violet → magenta → pink
        [
            Color(red: 0.42, green: 0.18, blue: 0.78),
            Color(red: 0.72, green: 0.28, blue: 0.78),
            Color(red: 0.95, green: 0.45, blue: 0.65),
        ],
        // 2: Cognitive — indigo → cyan → teal
        [
            Color(red: 0.20, green: 0.30, blue: 0.78),
            Color(red: 0.22, green: 0.55, blue: 0.85),
            Color(red: 0.30, green: 0.78, blue: 0.78),
        ],
        // 3: Behavioral — emerald → mint → amber
        [
            Color(red: 0.10, green: 0.50, blue: 0.45),
            Color(red: 0.40, green: 0.75, blue: 0.55),
            Color(red: 0.95, green: 0.78, blue: 0.42),
        ],
        // 4: amber → rose
        [
            Color(red: 0.92, green: 0.55, blue: 0.20),
            Color(red: 0.95, green: 0.40, blue: 0.50),
            Color(red: 0.85, green: 0.30, blue: 0.65),
        ],
        // 5: deep blue → purple
        [
            Color(red: 0.15, green: 0.25, blue: 0.65),
            Color(red: 0.40, green: 0.30, blue: 0.85),
            Color(red: 0.65, green: 0.40, blue: 0.95),
        ],
        // 6: red → coral → gold
        [
            Color(red: 0.85, green: 0.25, blue: 0.45),
            Color(red: 0.95, green: 0.55, blue: 0.40),
            Color(red: 0.98, green: 0.78, blue: 0.42),
        ],
        // 7: teal → blue → violet
        [
            Color(red: 0.20, green: 0.55, blue: 0.65),
            Color(red: 0.30, green: 0.45, blue: 0.85),
            Color(red: 0.60, green: 0.40, blue: 0.92),
        ],
        // 8: forest → moss → sun
        [
            Color(red: 0.20, green: 0.40, blue: 0.30),
            Color(red: 0.45, green: 0.65, blue: 0.40),
            Color(red: 0.92, green: 0.85, blue: 0.50),
        ],
    ]

    static func gradient(for module: Module) -> [Color] {
        let idx = max(0, module.sortOrder - 1) % gradientPalette.count
        return gradientPalette[idx]
    }
}

// MARK: - Resume Target

private struct ResumeTarget {
    let lesson: Lesson
    let module: Module
    let eyebrow: String
    let ctaLabel: String
}

// MARK: - Header

private struct LearnHeader: View {
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Learn")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hero Card

private struct HeroCard: View {
    let target: ResumeTarget
    let gradient: [Color]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft glow orb (extends out, but offset doesn't affect layout)
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 100, y: -120)

            // Watermark icon
            Image(systemName: target.module.iconName)
                .font(.system(size: 180, weight: .light))
                .foregroundStyle(.white.opacity(0.13))
                .offset(x: 60, y: 50)

            VStack(alignment: .leading, spacing: 14) {
                Text(target.eyebrow)
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                Text(target.lesson.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Image(systemName: target.module.iconName)
                        .font(.caption2)
                    Text(target.module.title)
                        .font(.subheadline.weight(.semibold))
                    Text("·")
                        .font(.subheadline)
                    Text("\(target.lesson.estimatedMinutes) min")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                    Text(target.ctaLabel)
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(gradient.first ?? .black)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: gradient.last?.opacity(0.35) ?? .clear, radius: 24, x: 0, y: 12)
    }
}

// MARK: - Stats Pill

private struct StatsPill: View {
    let lessonsDone: Int
    let minutesDone: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "checkmark.seal.fill",
                tint: Color(red: 0.45, green: 0.92, blue: 0.65),
                value: "\(lessonsDone)",
                label: "lessons"
            )
            divider
            statItem(
                icon: "clock.fill",
                tint: Color(red: 0.65, green: 0.78, blue: 0.98),
                value: minutesLabel,
                label: "spent"
            )
            divider
            statItem(
                icon: "flame.fill",
                tint: Color(red: 0.98, green: 0.62, blue: 0.40),
                value: "\(streakDays)d",
                label: "streak"
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statItem(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 22)
    }

    private var minutesLabel: String {
        if minutesDone < 60 { return "\(minutesDone)m" }
        let h = minutesDone / 60
        let m = minutesDone % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - Module Cover Card

private struct ModuleCoverCard: View {
    let module: Module
    let lessonCount: Int
    let completedCount: Int
    let gradient: [Color]

    private var isComplete: Bool {
        lessonCount > 0 && completedCount >= lessonCount
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Watermark icon — bottom-right, low opacity, large
            Image(systemName: module.iconName)
                .font(.system(size: 150, weight: .light))
                .foregroundStyle(.white.opacity(0.16))
                .offset(x: 60, y: 30)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MODULE \(String(format: "%02d", module.sortOrder))")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    if isComplete {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("DONE")
                                .font(.caption2.weight(.bold))
                                .tracking(1.5)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.20))
                        .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 12)

                Text(module.title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 14)

                if lessonCount > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<lessonCount, id: \.self) { i in
                            Capsule()
                                .fill(i < completedCount ? Color.white : Color.white.opacity(0.22))
                                .frame(height: 4)
                        }
                    }
                    .padding(.bottom, 8)
                }

                HStack(spacing: 12) {
                    Text("\(lessonCount) lesson\(lessonCount == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 3, height: 3)
                    Text("\(module.estimatedMinutes) min")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: gradient.last?.opacity(0.30) ?? .clear, radius: 18, x: 0, y: 10)
    }
}
