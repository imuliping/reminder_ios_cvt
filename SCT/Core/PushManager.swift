//
//  PushManager.swift
//  iOS replacement for shared/SCTFirebaseMessagingServices.kt.
//
//  Firebase Cloud Messaging is Android-only, so the push path here is APNs +
//  UserNotifications. The *routing* logic — which bus event each push type
//  triggers and which screen it deep-links to — is ported verbatim from
//  SctFirebaseMessagingService.onMessageReceived().
//

import Foundation
import UIKit
import UserNotifications

/// Set by a push so AppNavigator can jump to the right screen, mirroring the
/// `putExtra("screen", …)` the Android notification intent carried.
final class PushRouting: ObservableObject {
    static let shared = PushRouting()
    @Published var pendingScreen: String?
    private init() {}
}

final class PushManager: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static let shared = PushManager()

    /// Notification "channel" name kept for parity with the Android constants.
    static let CHANNEL_ID = "sct_notifications"
    static let CHANNEL_NAME = "SCT Notifications"

    /// Latest APNs token, registered with the backend after login.
    private(set) var deviceToken: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
        return true
    }

    /// Android requested POST_NOTIFICATIONS in MainActivity.onCreate; same timing here.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                LogManager.logError("Notification authorization failed: \(error.localizedDescription)")
            }
            LogManager.logInfo("Notification authorization granted=\(granted)")
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // ── APNs token ────────────────────────────────────────────────

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        LogManager.logInfo("APNs token: \(token.take(20))…")
        // If the user is already signed in, register immediately; otherwise
        // LoginViewModel registers it right after a successful login.
        if TokenManager.isLoggedIn() {
            Task { await registerDeviceToken(token) }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogManager.logError("Failed to get APNs token: \(error.localizedDescription)")
    }

    // ── Incoming push ─────────────────────────────────────────────

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handle(userInfo: userInfo, showLocalNotification: application.applicationState != .active)
        completionHandler(.newData)
    }

    /// Foreground presentation — Android always posted a heads-up notification,
    /// so show the banner here too.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handle(userInfo: notification.request.content.userInfo, showLocalNotification: false)
        completionHandler([.banner, .sound, .list])
    }

    /// Tapping a notification — equivalent of the PendingIntent that relaunched
    /// MainActivity with the "screen" extra.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let screen = (userInfo["screen"] as? String) ?? ""
        if screen.isNotBlank {
            DispatchQueue.main.async { PushRouting.shared.pendingScreen = screen }
        }
        handle(userInfo: userInfo, showLocalNotification: false)
        completionHandler()
    }

    // ── Routing — ported from onMessageReceived() ─────────────────

    private func handle(userInfo: [AnyHashable: Any], showLocalNotification: Bool) {
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]

        let title = (alert?["title"] as? String)
            ?? (userInfo["title"] as? String)
            ?? "SCT Reminder"
        let body = (alert?["body"] as? String)
            ?? (userInfo["body"] as? String)
            ?? ""
        var screen = (userInfo["screen"] as? String) ?? ""
        let type = (userInfo["type"] as? String) ?? ""

        LogManager.logInfo("Push received: type=\(type) title=\(title)")

        let bus = NotificationEventBus.shared

        func matches(_ values: String...) -> Bool {
            values.contains { $0.compare(type, options: .caseInsensitive) == .orderedSame }
        }

        // ── Team chat message ─────────────────────────────────────
        if matches("TEAM_CHAT") || title.range(of: "Chat", options: .caseInsensitive) != nil {
            if screen.isBlank { screen = "group_chat" }
            bus.triggerChatRefresh()
        }
        // ── Task assignment offer ─────────────────────────────────
        else if matches("TASK_OFFER", "TASK_ASSIGNMENT")
                    || title.range(of: "assigned", options: .caseInsensitive) != nil {
            if screen.isBlank { screen = "schedule" }
            bus.triggerScheduleRefresh()
        }
        // ── Task reminder ─────────────────────────────────────────
        else if matches("TASK_REMINDER", "REMINDER") {
            if screen.isBlank { screen = "myday" }
            bus.triggerScheduleRefresh()
        }
        // ── Alarm ─────────────────────────────────────────────────
        else if matches("ALARM") {
            if screen.isBlank { screen = "myday" }
            bus.triggerScheduleRefresh()
            bus.triggerNotificationRefresh()
        }
        // ── Notification inbox update ─────────────────────────────
        else if matches("NOTIFICATION", "ALERT", "ESCALATION", "TASK_ESCALATION", "DAILY_INCOMPLETE") {
            if screen.isBlank { screen = "notifications" }
            bus.triggerNotificationRefresh()
        }
        // ── Task completed / status update ────────────────────────
        else if matches("TASK_COMPLETED", "TASK_STATUS") {
            bus.triggerScheduleRefresh()
        }

        if showLocalNotification {
            show(title: title, body: body, screen: screen)
        }
    }

    /// Equivalent of showNotification() — only needed for silent/data-only pushes,
    /// since APNs renders alert payloads itself.
    private func show(title: String, body: String, screen: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if screen.isNotBlank { content.userInfo = ["screen": screen] }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
