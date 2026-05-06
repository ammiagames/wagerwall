import Foundation

/// Aggregate streak metrics for the Profile tab. Returned by the
/// `get_user_streak_stats` Postgres RPC.
struct StreakStats: Codable, Sendable {
    let currentStreakDays: Int
    let longestStreakDays: Int
    let averageStreakDays: Double
    let totalStreaks: Int
    let percentile: Double
    let totalUsers: Int

    static let empty = StreakStats(
        currentStreakDays: 0,
        longestStreakDays: 0,
        averageStreakDays: 0,
        totalStreaks: 0,
        percentile: 0,
        totalUsers: 0
    )
}
