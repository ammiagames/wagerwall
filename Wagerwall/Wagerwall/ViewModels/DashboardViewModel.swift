import Foundation
import Supabase

@Observable
final class DashboardViewModel {
    var streak: UserStreak?
    var profile: UserProfile?
    var todaysMood: MoodLog?
    var recentUrges: [UrgeLog] = []
    var isLoading = true
    var error: String?

    private let profileRepo: any UserProfileRepository
    private let streakRepo: any StreakRepository
    private let moodRepo: any MoodLogRepository
    private let urgeRepo: any UrgeLogRepository

    init(
        profileRepo: any UserProfileRepository,
        streakRepo: any StreakRepository,
        moodRepo: any MoodLogRepository,
        urgeRepo: any UrgeLogRepository
    ) {
        self.profileRepo = profileRepo
        self.streakRepo = streakRepo
        self.moodRepo = moodRepo
        self.urgeRepo = urgeRepo
    }

    // MARK: - Computed

    var streakDays: Int { streak?.currentStreakDays ?? 0 }

    var moneySaved: Double { streak?.moneySavedEstimate ?? 0 }

    var dailySpend: Double { profile?.dailyGamblingSpend ?? 0 }

    var estimatedSavings: Double {
        guard let quitDate = profile?.quitDate else { return moneySaved }
        let days = Calendar.current.dateComponents([.day], from: quitDate, to: Date()).day ?? 0
        return Double(max(days, 0)) * dailySpend
    }

    var todaysUrgeCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return recentUrges.filter { ($0.loggedAt ?? .distantPast) >= startOfDay }.count
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good Morning"
        case 12..<17: timeGreeting = "Good Afternoon"
        default: timeGreeting = "Good Evening"
        }
        if let name = profile?.displayName, !name.isEmpty {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    var streakMessage: String {
        switch streakDays {
        case 0: return "Your journey starts today"
        case 1...6: return "Building momentum — keep going!"
        case 7...29: return "You're building a new pattern. Stay strong."
        case 30...89: return "A full month! You're rewriting your story."
        default: return "Incredible resilience. You're an inspiration."
        }
    }

    static var dailyQuote: (text: String, author: String) {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let quotes = PanicButtonViewModel.motivationalQuotes
        return quotes[dayOfYear % quotes.count]
    }

    // MARK: - Loading

    func load(userId: UUID) async {
        isLoading = true
        error = nil

        async let profileResult = profileRepo.fetchProfile(userId: userId)
        async let streakResult = streakRepo.fetchStreak(userId: userId)
        async let moodResult = moodRepo.fetchTodaysLog(userId: userId)
        async let urgeResult = urgeRepo.fetchLogs(userId: userId, limit: 20)

        do {
            profile = try await profileResult
            streak = try await streakResult
            todaysMood = try await moodResult
            recentUrges = try await urgeResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh(userId: UUID) async {
        await load(userId: userId)
    }

    func didLogMood(_ mood: MoodLog) {
        todaysMood = mood
    }

    func didLogUrge(_ urge: UrgeLog) {
        recentUrges.insert(urge, at: 0)
    }
}
