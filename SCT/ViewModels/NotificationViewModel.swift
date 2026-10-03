//
//  NotificationViewModel.swift
//  Port of shared/NotificationViewModel.kt.
//

import Foundation
import Combine

@MainActor
final class NotificationViewModel: ObservableObject {

    @Published var inboxState: UiState<[NotificationInboxItem]> = .idle

    /// Tracks which notification IDs currently have an action in flight, so the
    /// UI can disable buttons and show a spinner instead of letting impatient
    /// taps fire duplicate ack/dismiss/snooze requests while the first is still
    /// pending (these calls can take 10+ seconds during backend slowness).
    @Published var pendingActionIds: Set<String> = []
    @Published var actionError: String?
    @Published var actionNotice: String?

    /// Track which userId loaded the current data so we can detect user switches.
    private var loadedForUserId: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadNotifications()
        observeNotificationRefresh()
    }

    func loadNotifications() {
        Task {
            inboxState = .loading
            let currentUserId = TokenManager.getUserId()
            await AppRepository.getNotificationInbox().fold(
                onSuccess: { items in
                    loadedForUserId = currentUserId
                    LogManager.logInfo("Loaded \(items.count) notifications for userId=\(currentUserId ?? "nil")")
                    if let first = items.first {
                        LogManager.logInfo("First notif: id=\(first.notificationId) title=\(first.title ?? "nil") body=\(first.body ?? "nil") type=\(first.type ?? "nil")")
                    }
                    inboxState = .success(items.filter { !$0.hasUnavailableTask })
                },
                onFailure: { inboxState = .error($0.message.isEmpty ? "Failed to load notifications" : $0.message) }
            )
        }
    }

    /// Call this when the screen opens to reload if the user has changed.
    func loadIfUserChanged() {
        if TokenManager.getUserId() != loadedForUserId {
            loadNotifications()
        }
    }

    func acknowledge(_ notificationId: String) {
        guard !pendingActionIds.contains(notificationId) else { return }
        pendingActionIds.insert(notificationId)
        Task {
            actionError = nil
            let item = inboxState.data?.first { $0.notificationId == notificationId }
            let result = if item?.linkedTaskId != nil && item?.isCheckIn != true {
                await AppRepository.completeNotification(notificationId: notificationId)
            } else {
                await AppRepository.acknowledgeNotification(notificationId: notificationId)
            }
            await result
                .onSuccess { _ in
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    loadNotifications()
                }
                .onFailure { actionError = $0.message.isEmpty ? "Could not complete task. Please try again." : $0.message }
            pendingActionIds.remove(notificationId)
        }
    }

    func dismiss(_ notificationId: String) {
        guard !pendingActionIds.contains(notificationId) else { return }
        pendingActionIds.insert(notificationId)
        Task {
            await AppRepository.dismissNotification(notificationId: notificationId)
                .onSuccess { _ in loadNotifications() }
                .onFailure { LogManager.logError("dismiss failed: \($0.message)") }
            pendingActionIds.remove(notificationId)
        }
    }

    func snooze(_ notificationId: String, minutes: Int = 10) {
        guard !pendingActionIds.contains(notificationId) else { return }
        pendingActionIds.insert(notificationId)
        Task {
            await AppRepository.snoozeNotification(notificationId: notificationId, minutes: minutes)
                .onSuccess { _ in loadNotifications() }
                .onFailure { LogManager.logError("snooze failed: \($0.message)") }
            pendingActionIds.remove(notificationId)
        }
    }

    func cannotDo(_ notificationId: String) {
        guard !pendingActionIds.contains(notificationId) else { return }
        pendingActionIds.insert(notificationId)
        Task {
            actionError = nil
            await AppRepository.cannotDoNotification(notificationId: notificationId)
                .onSuccess { item in
                    actionNotice = item.checkInMessage ?? "Task marked unresolved."
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    loadNotifications()
                }
                .onFailure { actionError = $0.message.isEmpty ? "Could not request a check-in. Please try again." : $0.message }
            pendingActionIds.remove(notificationId)
        }
    }

    private func observeNotificationRefresh() {
        NotificationEventBus.shared.notificationRefreshEvents
            .sink { [weak self] _ in self?.loadNotifications() }
            .store(in: &cancellables)
    }
}
