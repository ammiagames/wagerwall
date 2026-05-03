import Foundation
import Supabase

@Observable
final class AccountabilityPartnerViewModel {
    var partners: [AccountabilityPartner] = []
    var activeDisableRequest: DisableRequest?
    var isLoading = true
    var isSaving = false
    var error: String?

    private let partnerRepo: any AccountabilityPartnerRepository
    private let disableRequestRepo: any DisableRequestRepository

    init(
        partnerRepo: any AccountabilityPartnerRepository,
        disableRequestRepo: any DisableRequestRepository
    ) {
        self.partnerRepo = partnerRepo
        self.disableRequestRepo = disableRequestRepo
    }

    // MARK: - Computed

    var activePartners: [AccountabilityPartner] {
        partners.filter { $0.status == .active }
    }

    var invitedPartners: [AccountabilityPartner] {
        partners.filter { $0.status == .invited }
    }

    var hasActivePartner: Bool {
        !activePartners.isEmpty
    }

    var hasActiveDisableRequest: Bool {
        activeDisableRequest != nil
    }

    var cooloffTimeRemaining: TimeInterval? {
        guard let request = activeDisableRequest else { return nil }
        let remaining = request.cooloffEndsAt.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }

    // MARK: - Loading

    func load(userId: UUID) async {
        isLoading = true
        error = nil

        do {
            async let partnersResult = partnerRepo.fetchPartners(userId: userId)
            async let requestResult = disableRequestRepo.fetchActiveRequest(userId: userId)

            partners = try await partnersResult
            activeDisableRequest = try await requestResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Invite Partner

    func invitePartner(userId: UUID, email: String) async -> Bool {
        isSaving = true
        error = nil

        let insert = AccountabilityPartnerInsert(
            userId: userId,
            partnerEmail: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let partner = try await partnerRepo.invitePartner(insert: insert)
            partners.insert(partner, at: 0)
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Remove Partner

    func removePartner(_ partner: AccountabilityPartner) async {
        do {
            try await partnerRepo.removePartner(partnerId: partner.id)
            partners.removeAll { $0.id == partner.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Disable Protection Request

    func requestDisableProtection(userId: UUID, cooloffHours: Int = 24) async -> Bool {
        isSaving = true
        error = nil

        let cooloffEndsAt = Date().addingTimeInterval(TimeInterval(cooloffHours * 3600))
        let insert = DisableRequestInsert(
            userId: userId,
            cooloffEndsAt: cooloffEndsAt
        )

        do {
            let request = try await disableRequestRepo.createRequest(insert: insert)
            activeDisableRequest = request
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func cancelDisableRequest() async {
        guard let request = activeDisableRequest else { return }
        do {
            try await disableRequestRepo.cancelRequest(requestId: request.id)
            activeDisableRequest = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
