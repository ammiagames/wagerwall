import SwiftUI
import Supabase

struct DisableProtectionView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let viewModel: AccountabilityPartnerViewModel

    @State private var cooloffHours: Int = 24
    @State private var confirmText: String = ""
    @State private var showConfirmation = false

    private let confirmPhrase = "DISABLE"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "shield.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Disable Protection")
                        .font(.title2.bold())

                    Text("This request will notify your accountability partner and start a cooling-off period before protection can be disabled.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Cooling-off period
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cooling-Off Period")
                        .font(.headline)

                    Picker("Hours", selection: $cooloffHours) {
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                        Text("48 hours").tag(48)
                        Text("72 hours").tag(72)
                    }
                    .pickerStyle(.segmented)

                    Text("You must wait this long after your partner approves before protection is actually disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                // Warning
                CardView(padding: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Think carefully")
                                .font(.subheadline.bold())
                            Text("Are you sure this isn't an urge talking? Consider using the Panic Button first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                WagerWallButton(
                    title: "Request Disable",
                    style: .outline,
                    isLoading: viewModel.isSaving
                ) {
                    showConfirmation = true
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Disable Protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Confirm Request", isPresented: $showConfirmation) {
                TextField("Type \(confirmPhrase) to confirm", text: $confirmText)
                Button("Cancel", role: .cancel) {
                    confirmText = ""
                }
                Button("Submit Request", role: .destructive) {
                    if confirmText.uppercased() == confirmPhrase {
                        Task { await submitRequest() }
                    }
                    confirmText = ""
                }
            } message: {
                Text("Type \(confirmPhrase) to confirm you want to request disabling protection. Your partner will be notified.")
            }
        }
    }

    private func submitRequest() async {
        guard let userId = auth.currentUserId else { return }
        let success = await viewModel.requestDisableProtection(
            userId: userId,
            cooloffHours: cooloffHours
        )
        if success {
            dismiss()
        }
    }
}
