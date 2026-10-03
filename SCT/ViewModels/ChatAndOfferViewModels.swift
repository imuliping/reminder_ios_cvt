//
//  ChatAndOfferViewModels.swift
//  Ports of the GroupChatViewModel in shared/GroupChatScreen.kt, the
//  OffersAssignedViewModel in shared/OffersAssignedScreen.kt and the
//  OffersForMeViewModel in family/FamilyOffersForMe.kt.
//

import Foundation
import Combine

// ── Group (team) chat ─────────────────────────────────────────────

@MainActor
final class GroupChatViewModel: ObservableObject {

    @Published var messagesState: UiState<[TeamChatMessage]> = .idle

    private var isInitialLoad = true
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadMessages()
        observePushes()
    }

    func loadMessages() {
        let familyId = TokenManager.getFamilyAccountId() ?? ""
        guard familyId.isNotBlank else {
            messagesState = .error("No valid family profile found.")
            return
        }
        Task {
            if isInitialLoad {
                messagesState = .loading
                isInitialLoad = false
            }
            await AppRepository.getTeamChatMessages(familyAccountId: familyId).fold(
                onSuccess: { messagesState = .success($0.reversed()) },
                onFailure: { messagesState = .error($0.message.isEmpty ? "Failed to load messages" : $0.message) }
            )
        }
    }

    func sendMessage(_ content: String) {
        guard content.isNotBlank else { return }
        let familyId = TokenManager.getFamilyAccountId() ?? ""
        Task {
            await AppRepository.sendTeamChatMessage(content: content, familyAccountId: familyId).fold(
                onSuccess: { _ in loadMessages() },
                onFailure: { _ in }
            )
        }
    }

    private func observePushes() {
        NotificationEventBus.shared.chatRefreshEvents
            .sink { [weak self] _ in
                guard let self else { return }
                let familyId = TokenManager.getFamilyAccountId()
                guard let familyId, familyId.isNotBlank else { return }
                Task { @MainActor in
                    await AppRepository.getTeamChatMessages(familyAccountId: familyId).onSuccess {
                        self.messagesState = .success($0.reversed())
                    }
                }
            }
            .store(in: &cancellables)
    }

    func isMyMessage(_ message: TeamChatMessage) -> Bool {
        let myUserId = TokenManager.getUserId()
        return message.senderId == myUserId || message.senderUserId == myUserId
    }
}

// ── Offers Assigned (offers I sent) ───────────────────────────────

@MainActor
final class OffersAssignedViewModel: ObservableObject {

    struct OfferWithTask: Identifiable {
        let offer: TaskAssignmentOffer
        let task: TaskItem?
        var id: String { offer.offerId }
    }

    @Published var offersState: UiState<[OfferWithTask]> = .idle

    /// userId → display name, built from the family members list + candidates.
    @Published var userNames: [String: String] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadOffers()
        observeRefresh()
    }

    private func observeRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadOffers() }
            .store(in: &cancellables)
    }

    func loadOffers() {
        Task {
            offersState = .loading

            let myUserId = TokenManager.getUserId() ?? ""
            let subjectId = TokenManager.isSenior() ? myUserId : (TokenManager.getSeniorUserId() ?? myUserId)
            let familyAccountId = TokenManager.getFamilyAccountId()

            async let familyResult: FamilyDetailResponse? = {
                guard let familyAccountId, familyAccountId.isNotBlank else { return nil }
                return await AppRepository.getFamily(familyAccountId: familyAccountId).getOrNull
            }()
            async let candidatesResult = AppRepository.getAssignmentCandidates()
            async let tasksResult = AppRepository.getTasks(subjectUserId: subjectId)
            async let offersResult = AppRepository.getMyOffers()

            // Build the name map from family members + candidates
            var names: [String: String] = [:]
            if let members = await familyResult?.members {
                for m in members {
                    guard let id = m.userId, let name = m.username ?? m.name else { continue }
                    names[id] = name
                }
            }
            for c in (await candidatesResult).getOrElse([]) {
                guard let id = c.userId, let name = c.displayName else { continue }
                names[id] = name
            }
            userNames = names

            let taskMap = Dictionary(
                (await tasksResult).getOrElse([]).map { ($0.taskId, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            await offersResult.fold(
                onSuccess: { allOffers in
                    LogManager.logInfo("getMyOffers: \(allOffers.count) total, myUserId=\(myUserId) subjectId=\(subjectId)")

                    let oneDayAgoMs = Date().timeIntervalSince1970 * 1000 - 24 * 60 * 60 * 1000
                    func updatedWithinDay(_ offer: TaskAssignmentOffer) -> Bool {
                        guard let ts = offer.updatedAt ?? offer.createdAt else { return true }
                        guard let millis = parseTimestampMillis(ts) else { return true }
                        return millis >= oneDayAgoMs
                    }

                    let filtered = allOffers.filter { offer in
                        let status = offer.status?.uppercased()
                        // Skip cancelled offers
                        if status == "CANCELED" { return false }
                        // "Offers Assigned" means offers I sent to someone else.
                        if offer.fromUserId != myUserId { return false }
                        // Defensive: skip any accidental self-assignments
                        if offer.toUserId == myUserId { return false }
                        // Only keep recent accepted offers to avoid clutter
                        if status == "ACCEPTED" { return updatedWithinDay(offer) }
                        return true
                    }

                    var seen = Set<String>()
                    let withTasks = filtered
                        .filter { seen.insert($0.offerId).inserted }
                        .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
                        .map { OfferWithTask(offer: $0, task: taskMap[$0.taskId]) }
                    offersState = .success(withTasks)
                },
                onFailure: { offersState = .error($0.message.isEmpty ? "Failed to load offers" : $0.message) }
            )
        }
    }
}

// ── Offers For Me (offers awaiting my response) ───────────────────

@MainActor
final class OffersForMeViewModel: ObservableObject {

    struct OfferForMe: Identifiable {
        let offer: TaskAssignmentOffer
        let taskTitle: String
        var id: String { offer.offerId }
    }

    @Published var offersState: UiState<[OfferForMe]> = .idle

    init() { loadOffers() }

    func loadOffers() {
        Task {
            offersState = .loading
            await AppRepository.getMyOffers(status: "PENDING").fold(
                onSuccess: { offers in
                    let sorted = offers.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
                    let withTitles = sorted.map { offer in
                        let title = offer.message?
                            .replacingOccurrences(of: "You've been assigned: ", with: "")
                            .nonBlank ?? "Task"
                        return OfferForMe(offer: offer, taskTitle: title)
                    }
                    offersState = .success(withTitles)
                },
                onFailure: { offersState = .error($0.message.isEmpty ? "Failed to load offers" : $0.message) }
            )
        }
    }

    func acceptOffer(offerId: String) {
        Task {
            await AppRepository.acceptOffer(offerId: offerId)
                .onSuccess { _ in
                    loadOffers()
                    // Notify schedule and shopping screens to refresh
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    NotificationEventBus.shared.triggerShoppingRefresh()
                }
                .onFailure { LogManager.logError("acceptOffer failed: \($0.message)") }
        }
    }

    func declineOffer(offerId: String) {
        Task {
            await AppRepository.declineOffer(offerId: offerId)
                .onSuccess { _ in
                    loadOffers()
                    // Without this, the sender never sees the decline reflected
                    // on their "Offers Assigned" screen.
                    NotificationEventBus.shared.triggerScheduleRefresh()
                }
                .onFailure { LogManager.logError("declineOffer failed: \($0.message)") }
        }
    }
}
