//
//  NotificationBus.swift
//  Port of shared/NotificationBus.kt — MutableSharedFlow becomes a Combine
//  PassthroughSubject, which has the same "hot, no replay" semantics.
//

import Combine
import Foundation

final class NotificationEventBus {
    static let shared = NotificationEventBus()
    private init() {}

    // ── Team chat refresh ─────────────────────────────────────────
    let chatRefreshEvents = PassthroughSubject<Void, Never>()
    func triggerChatRefresh() { chatRefreshEvents.send(()) }

    // ── Schedule/task refresh — fires when a task offer is received
    // or when a task reminder arrives. All schedule screens observe this.
    let scheduleRefreshEvents = PassthroughSubject<Void, Never>()
    func triggerScheduleRefresh() { scheduleRefreshEvents.send(()) }

    // ── Shopping list refresh — fires when an offer on a shopping task
    // is accepted or declined, so the list updates immediately.
    let shoppingRefreshEvents = PassthroughSubject<Void, Never>()
    func triggerShoppingRefresh() { shoppingRefreshEvents.send(()) }

    // ── Notification inbox refresh — fires when a new inbox item arrives
    let notificationRefreshEvents = PassthroughSubject<Void, Never>()
    func triggerNotificationRefresh() { notificationRefreshEvents.send(()) }
}
