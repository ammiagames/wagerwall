import SwiftUI
import Supabase

struct AccountabilityPartnersView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.accountabilityPartnerRepository) private var partnerRepo
    @Environment(\.disableRequestRepository) private var disableRequestRepo

    @State private var viewModel: AccountabilityPartnerViewModel?
    @State private var showInvite = false
    @State private var showDisableProtection = false

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading {
                partnersContent(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Accountability")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInvite = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .task { await loadPartners() }
        .refreshable { await refreshPartners() }
        .sheet(isPresented: $showInvite) {
            InvitePartnerView { success in
                if success {
                    Task { await refreshPartners() }
                }
            }
        }
        .sheet(isPresented: $showDisableProtection) {
            if let viewModel {
                DisableProtectionView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func partnersContent(_ vm: AccountabilityPartnerViewModel) -> some View {
        List {
            // Active partners
            if !vm.activePartners.isEmpty {
                Section("Active Partners") {
                    ForEach(vm.activePartners) { partner in
                        PartnerRow(partner: partner)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.removePartner(partner) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            // Invited partners
            if !vm.invitedPartners.isEmpty {
                Section("Pending Invitations") {
                    ForEach(vm.invitedPartners) { partner in
                        PartnerRow(partner: partner)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.removePartner(partner) }
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }
                            }
                    }
                }
            }

            // Empty state
            if vm.partners.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Partners Yet")
                            .font(.headline)
                        Text("Invite a trusted person to help keep you accountable. They'll be notified if protection is disabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            // Disable protection section
            if vm.hasActivePartner {
                Section {
                    if let request = vm.activeDisableRequest {
                        DisableRequestStatusView(request: request) {
                            Task { await vm.cancelDisableRequest() }
                        }
                    } else {
                        Button {
                            showDisableProtection = true
                        } label: {
                            Label("Request Protection Disable", systemImage: "shield.slash")
                                .foregroundStyle(.orange)
                        }
                    }
                } footer: {
                    Text("Disabling protection requires a cooling-off period and partner approval.")
                }
            }

            if let error = vm.error {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func loadPartners() async {
        guard let userId = auth.currentUserId else { return }
        let vm = AccountabilityPartnerViewModel(
            partnerRepo: partnerRepo,
            disableRequestRepo: disableRequestRepo
        )
        viewModel = vm
        await vm.load(userId: userId)
    }

    private func refreshPartners() async {
        guard let userId = auth.currentUserId else { return }
        await viewModel?.load(userId: userId)
    }
}

// MARK: - Partner Row

private struct PartnerRow: View {
    let partner: AccountabilityPartner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: partner.status == .active ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.clock")
                .font(.title2)
                .foregroundStyle(partner.status == .active ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.partnerEmail ?? "Partner")
                    .font(.subheadline.weight(.medium))

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if partner.status == .active {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: String {
        switch partner.status {
        case .invited: "Invitation pending"
        case .active:
            if let date = partner.activatedAt {
                "Active since \(date.formatted(.dateTime.month().day()))"
            } else {
                "Active"
            }
        case .removed: "Removed"
        }
    }
}
