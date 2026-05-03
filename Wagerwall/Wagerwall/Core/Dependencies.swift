import SwiftUI

// MARK: - Repository Environment Keys

private struct UserProfileRepositoryKey: EnvironmentKey {
    static let defaultValue: any UserProfileRepository = SupabaseUserProfileRepository()
}

private struct StreakRepositoryKey: EnvironmentKey {
    static let defaultValue: any StreakRepository = SupabaseStreakRepository()
}

private struct CBTRepositoryKey: EnvironmentKey {
    static let defaultValue: any CBTRepository = SupabaseCBTRepository()
}

private struct UrgeLogRepositoryKey: EnvironmentKey {
    static let defaultValue: any UrgeLogRepository = SupabaseUrgeLogRepository()
}

private struct MoodLogRepositoryKey: EnvironmentKey {
    static let defaultValue: any MoodLogRepository = SupabaseMoodLogRepository()
}

private struct HeartbeatRepositoryKey: EnvironmentKey {
    static let defaultValue: any HeartbeatRepository = SupabaseHeartbeatRepository()
}

private struct AccountabilityPartnerRepositoryKey: EnvironmentKey {
    static let defaultValue: any AccountabilityPartnerRepository = SupabaseAccountabilityPartnerRepository()
}

private struct BlockedAttemptRepositoryKey: EnvironmentKey {
    static let defaultValue: any BlockedAttemptRepository = SupabaseBlockedAttemptRepository()
}

private struct DisableRequestRepositoryKey: EnvironmentKey {
    static let defaultValue: any DisableRequestRepository = SupabaseDisableRequestRepository()
}

private struct PushTokenRepositoryKey: EnvironmentKey {
    static let defaultValue: any PushTokenRepository = SupabasePushTokenRepository()
}

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {
    var userProfileRepository: any UserProfileRepository {
        get { self[UserProfileRepositoryKey.self] }
        set { self[UserProfileRepositoryKey.self] = newValue }
    }

    var streakRepository: any StreakRepository {
        get { self[StreakRepositoryKey.self] }
        set { self[StreakRepositoryKey.self] = newValue }
    }

    var cbtRepository: any CBTRepository {
        get { self[CBTRepositoryKey.self] }
        set { self[CBTRepositoryKey.self] = newValue }
    }

    var urgeLogRepository: any UrgeLogRepository {
        get { self[UrgeLogRepositoryKey.self] }
        set { self[UrgeLogRepositoryKey.self] = newValue }
    }

    var moodLogRepository: any MoodLogRepository {
        get { self[MoodLogRepositoryKey.self] }
        set { self[MoodLogRepositoryKey.self] = newValue }
    }

    var heartbeatRepository: any HeartbeatRepository {
        get { self[HeartbeatRepositoryKey.self] }
        set { self[HeartbeatRepositoryKey.self] = newValue }
    }

    var accountabilityPartnerRepository: any AccountabilityPartnerRepository {
        get { self[AccountabilityPartnerRepositoryKey.self] }
        set { self[AccountabilityPartnerRepositoryKey.self] = newValue }
    }

    var blockedAttemptRepository: any BlockedAttemptRepository {
        get { self[BlockedAttemptRepositoryKey.self] }
        set { self[BlockedAttemptRepositoryKey.self] = newValue }
    }

    var disableRequestRepository: any DisableRequestRepository {
        get { self[DisableRequestRepositoryKey.self] }
        set { self[DisableRequestRepositoryKey.self] = newValue }
    }

    var pushTokenRepository: any PushTokenRepository {
        get { self[PushTokenRepositoryKey.self] }
        set { self[PushTokenRepositoryKey.self] = newValue }
    }
}
