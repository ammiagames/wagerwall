import SwiftUI
import Supabase

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo
    @Environment(\.streakRepository) private var streakRepo

    @State private var profile: UserProfile?
    @State private var streak: UserStreak?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                profileContent
            }
        }
        .navigationTitle("Profile")
        .task { await loadProfile() }
        .refreshable { await loadProfile() }
    }

    @ViewBuilder
    private var profileContent: some View {
        List {
            // User info header
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.displayName ?? "User")
                            .font(.title3.bold())
                        if let email = auth.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let severity = profile?.gamblingSeverity {
                            Text("Assessment: \(severity.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Stats
            Section("Recovery Stats") {
                if let streak {
                    HStack {
                        Label("Current Streak", systemImage: "flame.fill")
                        Spacer()
                        Text("\(streak.currentStreakDays) days")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Longest Streak", systemImage: "trophy.fill")
                        Spacer()
                        Text("\(streak.longestStreakDays) days")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Money Saved", systemImage: "dollarsign.circle.fill")
                        Spacer()
                        Text("$\(Int(streak.moneySavedEstimate))")
                            .foregroundStyle(.secondary)
                    }
                }

                if let quitDate = profile?.quitDate {
                    HStack {
                        Label("Quit Date", systemImage: "calendar")
                        Spacer()
                        Text(quitDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Self-Assessment
            Section("Self-Assessment") {
                NavigationLink {
                    AssessmentView()
                } label: {
                    HStack {
                        Label("PGSI Assessment", systemImage: "brain.head.profile")
                        Spacer()
                        if let severity = profile?.gamblingSeverity {
                            Text(severity.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not taken")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Accountability
            Section("Accountability") {
                NavigationLink {
                    AccountabilityPartnersView()
                } label: {
                    Label("Accountability Partners", systemImage: "person.2.fill")
                }
            }

            // Settings
            Section("Settings") {
                NavigationLink {
                    EditProfileView(profile: profile)
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("App Settings", systemImage: "gearshape")
                }

                NavigationLink {
                    CrisisResourcesView()
                } label: {
                    Label("Crisis Resources", systemImage: "phone.arrow.up.right")
                        .foregroundStyle(.primary)
                }
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    Task { await auth.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    private func loadProfile() async {
        guard let userId = auth.currentUserId else { return }
        do {
            async let profileResult = profileRepo.fetchProfile(userId: userId)
            async let streakResult = streakRepo.fetchStreak(userId: userId)
            profile = try await profileResult
            streak = try await streakResult
        } catch {
            // Silently handle — profile may not exist yet
        }
        isLoading = false
    }
}
