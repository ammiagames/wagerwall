import SwiftUI
import Supabase

struct EditProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile?

    @State private var displayName: String = ""
    @State private var dailySpend: String = ""
    @State private var quitDate: Date = Date()
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Display Name") {
                TextField("Your name", text: $displayName)
            }

            Section("Recovery Details") {
                DatePicker("Quit Date", selection: $quitDate, in: ...Date(), displayedComponents: .date)

                HStack {
                    Text("Daily Spend")
                    Spacer()
                    TextField("$0", text: $dailySpend)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            if let error {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            if let profile {
                displayName = profile.displayName ?? ""
                dailySpend = profile.dailyGamblingSpend.map { String(Int($0)) } ?? ""
                quitDate = profile.quitDate ?? Date()
            }
        }
    }

    private func saveProfile() async {
        guard let userId = auth.currentUserId else { return }
        isSaving = true
        error = nil

        let update = UserProfileUpdate(
            displayName: displayName.isEmpty ? nil : displayName,
            quitDate: quitDate,
            dailyGamblingSpend: Double(dailySpend)
        )

        do {
            _ = try await profileRepo.updateProfile(userId: userId, update: update)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}
