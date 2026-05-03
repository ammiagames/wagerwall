import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            Section("Notifications") {
                Label("Push Notifications", systemImage: "bell.badge")
                    .foregroundStyle(.secondary)
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    CrisisResourcesView()
                } label: {
                    Label("Crisis Resources", systemImage: "heart.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Label("Delete Account", systemImage: "trash")
                        if isDeleting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account, recovery data, and all progress. This cannot be undone.")
        }
    }

    private func deleteAccount() async {
        guard let userId = auth.currentUserId else { return }
        isDeleting = true
        do {
            try await profileRepo.deleteAccount(userId: userId)
            await auth.signOut()
        } catch {
            // Account deletion failed — user stays signed in
        }
        isDeleting = false
    }
}
