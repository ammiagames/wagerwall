import SwiftUI
import Supabase

struct InvitePartnerView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.accountabilityPartnerRepository) private var partnerRepo
    @Environment(\.disableRequestRepository) private var disableRequestRepo
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isSaving = false
    @State private var error: String?

    var onComplete: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Invite a Partner")
                        .font(.title2.bold())

                    Text("Your accountability partner will receive notifications if you try to disable WagerWall's protections.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Partner's Email")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("partner@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 24)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                WagerWallButton(
                    title: "Send Invitation",
                    isLoading: isSaving,
                    isDisabled: !isValidEmail
                ) {
                    Task { await sendInvitation() }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Invite Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func sendInvitation() async {
        guard let userId = auth.currentUserId else { return }
        isSaving = true
        error = nil

        let vm = AccountabilityPartnerViewModel(
            partnerRepo: partnerRepo,
            disableRequestRepo: disableRequestRepo
        )
        let success = await vm.invitePartner(userId: userId, email: email)

        if success {
            onComplete(true)
            dismiss()
        } else {
            error = vm.error ?? "Failed to send invitation"
        }

        isSaving = false
    }
}
