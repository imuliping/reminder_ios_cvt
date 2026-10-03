//
//  AppNavigator.swift
//  Port of AppNavigator() in shared/MainActivity.kt.
//
//  The Android app deliberately used a single `currentScreen` string instead of
//  a nav graph, so the same model is kept here: one @Published route plus a
//  switch. Every route string is identical to the Kotlin original.
//

import SwiftUI

final class Router: ObservableObject {
    @Published var route: String = "login"

    func go(_ route: String) { self.route = route }
}

struct AppNavigator: View {

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = Router()
    @StateObject private var loginVM = LoginViewModel()
    @StateObject private var fontSize = AppFontSize.shared       // re-renders on font-size change
    @StateObject private var pushRouting = PushRouting.shared

    var body: some View {
        content
            .simultaneousGesture(TapGesture().onEnded { recordActivity() })
            .onChange(of: router.route) { _, newValue in
                LogManager.setScreen(newValue)
                recordActivity()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { enforceAutoLogout() }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    enforceAutoLogout()
                }
            }
            .onChange(of: pushRouting.pendingScreen) { _, screen in
                // A tapped notification carried a "screen" extra — honour it once.
                guard let screen, screen.isNotBlank else { return }
                router.go(mapPushScreen(screen))
                pushRouting.pendingScreen = nil
            }
            .environmentObject(router)
    }

    private func recordActivity() {
        guard TokenManager.isLoggedIn() else { return }
        TokenManager.saveLastActivity()
        Task { _ = await AppRepository.recordSessionActivity() }
    }

    private func enforceAutoLogout() {
        let minutes = TokenManager.getAutoLogoutMinutes()
        guard minutes > 0, TokenManager.isLoggedIn(),
              let lastActivity = TokenManager.getLastActivity(),
              Date().timeIntervalSince(lastActivity) >= Double(minutes * 60) else { return }
        Task {
            await unregisterDeviceToken()
            _ = await AppRepository.revokeSession()
            AppRepository.logout()
            router.go("login")
        }
    }

    /// Push payloads use generic screen names; map them onto the role-specific routes.
    private func mapPushScreen(_ screen: String) -> String {
        if TokenManager.isFamilyMember() {
            switch screen {
            case "group_chat":    return "family_chat"
            case "schedule":      return "family_schedule"
            case "myday":         return "family_home"
            case "notifications": return "family_notifications"
            default:              return screen
            }
        }
        if TokenManager.isCaregiver() {
            switch screen {
            case "group_chat":    return "caregiver_chat"
            case "schedule":      return "caregiver_schedule"
            case "myday":         return "caregiver_home"
            case "notifications": return "caregiver_notifications"
            default:              return screen
            }
        }
        switch screen {
        case "group_chat": return "chat"
        default:           return screen
        }
    }

    @ViewBuilder
    private var content: some View {
        switch router.route {

        // ── Auth ──────────────────────────────────────────────────
        case "login":
            LoginView(
                vm: loginVM,
                onLoginSuccess: {
                    switch TokenManager.getRoleId()?.lowercased().trimmingCharacters(in: .whitespaces) {
                    case "family member", "trusted co-manager", "trusted co manager", "spouse":
                        router.go("family_home")
                    case "caregiver", "professional caregiver":
                        router.go("caregiver_home")
                    default:
                        router.go("home")
                    }
                },
                onSignupClick: { router.go("signup") },
                onForgotPasswordClick: { router.go("forgot_password") }
            )

        case "signup":
            SignupView(
                onSignupSuccess: {
                    switch TokenManager.getRoleId()?.lowercased().trimmingCharacters(in: .whitespaces) {
                    case "family member", "trusted co-manager", "trusted co manager", "spouse":
                        router.go("family_home")
                    case "caregiver":     router.go("caregiver_home")
                    default:              router.go("home")
                    }
                },
                onBack: { router.go("login") }
            )

        case "forgot_password":
            ForgotPasswordView(
                onBack: { router.go("login") },
                onResetComplete: { router.go("login") }
            )

        case "notification_settings":
            NotificationSettingsView(
                onBack: { router.go(profileRouteForRole()) },
                onNavigate: { router.go($0) }
            )

        case "general_settings":
            GeneralSettingsView(
                onBack: { router.go(profileRouteForRole()) },
                onNavigate: { router.go($0) }
            )

        case "relative_accounts":
            RelativeAccountsView(onBack: { router.go(profileRouteForRole()) })

        // ── Senior ────────────────────────────────────────────────
        case "home":
            SeniorHomeView(
                onNavigate: { router.go($0) },
                onScheduleClick: { router.go("schedule") },
                onShopListClick: { router.go("shopping") },
                onNotificationClick: { router.go("notifications") },
                onProfileClick: { router.go("profile") }
            )

        case "myday":
            MyDayView(onNavigate: { router.go($0) })

        case "schedule":
            ScheduleView(onBack: { router.go("home") }, onNavigate: { router.go($0) })

        case "shopping":
            ShoppingListView(onBack: { router.go("home") }, onNavigate: { router.go($0) }, canAssign: true)

        case "notifications":
            NotificationView(onBack: { router.go("home") }, onNavigate: { router.go($0) })

        case "profile":
            AboutMeView(onBack: { router.go("home") },
                        onLogout: { loginVM.logout(); router.go("login") },
                        onNavigate: { router.go($0) })

        case "profile_detail":
            ProfileDetailView(onBack: { router.go("profile") })

        case "accept_invite":
            AcceptInviteView(onBack: { router.go("profile") }, onAccepted: { router.go("profile") })

        case "security":
            SecurityView(onBack: { router.go("profile") })

        case "reset_settings":
            ResetView(onBack: { router.go("profile") })

        case "chat":
            GroupChatView(onNavigate: { router.go($0) }, isFamilyMember: false)

        case "aichat", "aichat/home", "aichat/schedule", "aichat/myday",
             "aichat/notifications", "aichat/shopping":
            AIChatView(onBack: { router.go("home") }, onNavigate: { router.go($0) },
                       navType: .senior, sourceScreen: sourceScreen(from: router.route))

        // ── Family ────────────────────────────────────────────────
        case "family_home":
            FamilyHomeView(
                onNavigate: { router.go($0) },
                onScheduleClick: { router.go("family_schedule") },
                onShopListClick: { router.go("family_shopping") },
                onNotificationClick: { router.go("family_notifications") },
                onProfileClick: { router.go("family_profile") }
            )

        case "supervise":
            SuperviseView(
                onBack: { router.go("family_home") },
                onNavigate: { route in
                    if route != "family_schedule" { router.go(route) }
                }
            )

        case "family_schedule":
            FamilyScheduleView(onBack: { router.go("family_home") }, onNavigate: { router.go($0) })

        case "family_shopping":
            ShoppingListView(onBack: { router.go("family_home") }, onNavigate: { router.go($0) }, canAssign: true)

        case "family_notifications":
            FamilyNotificationView(onBack: { router.go("family_home") }, onNavigate: { router.go($0) })

        case "family_profile":
            AboutMeView(onBack: { router.go("family_home") },
                        onLogout: { loginVM.logout(); router.go("login") },
                        onNavigate: { router.go($0) })

        case "family_chat":
            GroupChatView(onNavigate: { router.go($0) }, isFamilyMember: true)

        case "family_aichat", "family_aichat/family_home", "family_aichat/family_schedule",
             "family_aichat/family_shopping", "family_aichat/family_supervise":
            AIChatView(onBack: { router.go("family_home") }, onNavigate: { router.go($0) },
                       navType: .family, sourceScreen: sourceScreen(from: router.route))

        case "family_report":
            FamilyReportView(onBack: { router.go("family_home") }, onNavigate: { router.go($0) })

        case "family_offers_assigned":
            OffersAssignedView(onBack: { router.go("family_home") })

        case "family_offers_for_me":
            OffersForMeView(onBack: { router.go("family_home") })

        case "senior_offers_assigned":
            OffersAssignedView(onBack: { router.go("home") })

        case "caregiver_offers_for_me":
            OffersForMeView(onBack: { router.go("caregiver_home") })

        case "caregiver_offers_assigned":
            OffersAssignedView(onBack: { router.go("caregiver_home") })

        // ── Caregiver ─────────────────────────────────────────────
        case "caregiver_home":
            CaregiverHomeView(
                onNavigate: { router.go($0) },
                onReportClick: { router.go("caregiver_report") },
                onShopListClick: { router.go("caregiver_shopping") },
                onAvailableTimeClick: { router.go("caregiver_available_time") },
                onNotificationClick: { router.go("caregiver_notifications") },
                onProfileClick: { router.go("caregiver_profile") }
            )

        case "caregiver_available_time":
            CaregiverAvailableTimeView(
                onBack: { router.go("caregiver_home") },
                onAddTask: { router.go("caregiver_schedule") },
                onNavigate: { router.go($0) }
            )

        case "caregiver_schedule":
            CaregiverScheduleView(onBack: { router.go("caregiver_home") }, onNavigate: { router.go($0) })

        case "caregiver_shopping":
            ShoppingListView(onBack: { router.go("caregiver_home") }, onNavigate: { router.go($0) }, canAssign: false)

        case "caregiver_notifications":
            FamilyNotificationView(onBack: { router.go("caregiver_home") }, onNavigate: { router.go($0) })

        case "caregiver_profile":
            AboutMeView(onBack: { router.go("caregiver_home") },
                        onLogout: { loginVM.logout(); router.go("login") },
                        onNavigate: { router.go($0) })

        case "caregiver_chat":
            GroupChatView(onNavigate: { router.go($0) }, isFamilyMember: true)

        case "caregiver_aichat", "caregiver_aichat/caregiver_home", "caregiver_aichat/caregiver_schedule":
            AIChatView(onBack: { router.go("caregiver_home") }, onNavigate: { router.go($0) },
                       navType: .caregiver, sourceScreen: sourceScreen(from: router.route))

        case "caregiver_report":
            CaregiverReportView(onBack: { router.go("caregiver_home") }, onNavigate: { router.go($0) })

        default:
            // Unknown route — Compose's `when` simply rendered nothing.
            EmptyView()
        }
    }

    /// `currentScreen.substringAfter("/", "home")`
    private func sourceScreen(from route: String) -> String {
        guard let idx = route.firstIndex(of: "/") else { return "home" }
        return String(route[route.index(after: idx)...])
    }

    private func profileRouteForRole() -> String {
        if TokenManager.isFamilyMember() { return "family_profile" }
        if TokenManager.isCaregiver()    { return "caregiver_profile" }
        return "profile"
    }
}
