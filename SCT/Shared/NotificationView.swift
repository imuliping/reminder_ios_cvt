//
//  NotificationView.swift
//  Port of shared/NotificationScreen.kt, including NotificationCard which the
//  family/caregiver notification screen also reuses.
//

import SwiftUI

struct NotificationView: View {

    let onBack: () -> Void
    var onNavigate: (String) -> Void = { _ in }
    @StateObject private var vm = NotificationViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NotificationHeader(onBack: onBack, onRefresh: { vm.loadNotifications() })
            Spacer().frame(height: 8)
            NotificationList(vm: vm, eldaRoute: "aichat/notifications", onNavigate: onNavigate)
        }
        .padding(16)
        .background(AppBg)
        .onAppear { vm.loadIfUserChanged() }
    }
}

/// Port of family/FamilyNotificationScreen.kt — identical body, different
/// Elda route (and no bottom nav, matching the Android comment).
struct FamilyNotificationView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = NotificationViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NotificationHeader(onBack: onBack, onRefresh: { vm.loadNotifications() })
            Spacer().frame(height: 8)
            NotificationList(vm: vm, eldaRoute: "family_aichat", onNavigate: onNavigate)
        }
        .padding(16)
        .background(AppBg)
        .onAppear { vm.loadIfUserChanged() }
    }
}

// ── Shared pieces ─────────────────────────────────────────────────

private struct NotificationHeader: View {
    let onBack: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TextDark)
                    .padding(8)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Notifications").font(appFont(20, .bold))
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17))
                    .foregroundStyle(TextDark)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotificationList: View {
    @ObservedObject var vm: NotificationViewModel
    let eldaRoute: String
    let onNavigate: (String) -> Void
    @State private var selectedTaskId: String?

    var body: some View {
        Group {
            switch vm.inboxState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()

            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadNotifications() }
                Spacer()

            case .success(let notifications):
                if notifications.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(.lightGray))
                        Text("No notifications right now.")
                            .font(appFont(15)).foregroundStyle(TextGray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let actionError = vm.actionError {
                                Text(actionError).font(appFont(13)).foregroundStyle(DangerRed)
                            }
                            if let actionNotice = vm.actionNotice {
                                Text(actionNotice).font(appFont(13)).foregroundStyle(AppGreen)
                            }
                            ForEach(notifications, id: \.notificationId) { n in
                                let isPending = vm.pendingActionIds.contains(n.notificationId)
                                NotificationCard(
                                    notification: n,
                                    isPending: isPending,
                                    onAcknowledge: { if !isPending { vm.acknowledge(n.notificationId) } },
                                    onDismiss: { if !isPending { vm.dismiss(n.notificationId) } },
                                    onSnooze: { if !isPending { vm.snooze(n.notificationId) } },
                                    onCannotDo: { if !isPending { vm.cannotDo(n.notificationId) } },
                                    onViewTask: { selectedTaskId = n.linkedTaskId }
                                )
                            }
                            Spacer().frame(height: 8)
                            MessageEldaBar { onNavigate(eldaRoute) }
                        }
                    }
                }

            default:
                Spacer()
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedTaskId != nil },
            set: { if !$0 { selectedTaskId = nil } }
        )) {
            NotificationTaskSheet(taskId: selectedTaskId ?? "") {
                selectedTaskId = nil
                vm.loadNotifications()
            }
        }
    }
}

struct NotificationCard: View {

    let notification: NotificationInboxItem
    var isPending: Bool = false
    let onAcknowledge: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onCannotDo: () -> Void
    let onViewTask: () -> Void

    private var priorityColor: Color {
        if notification.escalated { return DangerRed }
        if !notification.acknowledged { return AppGreen }
        return Color(hex: 0x9E9E9E)
    }

    private var badge: (String, String, Color) {
        switch notification.type?.uppercased() {
        case "TASK_REMINDER":    return ("🔔", "Reminder",      Color(hex: 0x1976D2))
        case "TASK_ESCALATION":  return ("⚠️", "Escalation",    DangerRed)
        case "DAILY_INCOMPLETE": return ("📋", "Daily Summary", Color(hex: 0xFF8F00))
        case "TASK_OVERDUE":     return ("⏰", "Overdue",       DangerRed)
        case "TASK_SCHEDULE":    return ("📅", "Upcoming",      Color(hex: 0x1976D2))
        case "ALARM":            return ("🚨", "Alarm",         DangerRed)
        case "NOTIFICATION":     return ("📣", "Notification",  Color(hex: 0x388E3C))
        case "TEAM_CHAT":        return ("💬", "Team Chat",     Color(hex: 0x7B1FA2))
        case "TASK_OFFER", "TASK_ASSIGNMENT":
                                 return ("📌", "Assignment",    Color(hex: 0x0288D1))
        default:                 return ("🔔", "Notification",  Color(hex: 0x9E9E9E))
        }
    }

    var body: some View {
        let displayTitle = notification.displayTitle ?? ""
        let displayBody = notification.body ?? ""

        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(height: 4)

            Spacer().frame(height: 12)

            HStack {
                HStack(spacing: 4) {
                    Text(badge.0).font(appFont(13))
                    Text(badge.1).font(appFont(12, .semibold)).foregroundStyle(badge.2)
                }
                Spacer()
                if let scheduledTime = notification.scheduledTime, scheduledTime.isNotEmpty {
                    Text(formatNotificationTime(scheduledTime))
                        .font(appFont(13)).foregroundStyle(TextGray)
                }
            }

            Spacer().frame(height: 8)

            if displayTitle.isNotEmpty {
                Text(displayTitle).font(appFont(20, .bold))
                Divider().padding(.vertical, 8)
            }

            if displayBody.isNotEmpty {
                Text(displayBody).font(appFont(14)).foregroundStyle(TextGray)
                Spacer().frame(height: 8)
            }

            if notification.escalated {
                Text("⚠️ Escalated — please respond urgently")
                    .font(appFont(13, .bold))
                    .foregroundStyle(DangerRed)
                Spacer().frame(height: 8)
            }

            Spacer().frame(height: 4)

            if notification.linkedTaskId != nil && notification.isCheckIn != true {
                if notification.taskAvailable == false {
                    Text("This task is no longer available.")
                        .font(appFont(13)).foregroundStyle(TextGray)
                } else {
                    Button("View task", action: onViewTask)
                        .font(appFont(14, .semibold))
                }
                Spacer().frame(height: 8)
            }

            if !notification.acknowledged {
                Button(action: onAcknowledge) {
                    ZStack {
                        if isPending {
                            ProgressView().tint(.white)
                        } else {
                            Text(notification.linkedTaskId != nil && notification.isCheckIn != true
                                 ? "Mark completed" : "Acknowledge")
                                .font(appFont(15, .bold)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(isPending ? AppGreen.opacity(0.6) : AppGreen)
                    .rounded(50)
                }
                .buttonStyle(.plain)
                .disabled(isPending || notification.taskAvailable == false)

                Spacer().frame(height: 8)

                HStack(spacing: 8) {
                    Button(action: onSnooze) {
                        Text("Snooze 10 min")
                            .font(appFont(13))
                            .foregroundStyle(TextDark)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .roundedBorder(BorderGray, 1, radius: 50)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(appFont(13))
                            .foregroundStyle(DangerRed)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .roundedBorder(DangerRed, 1, radius: 50)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)
                }

                if notification.linkedTaskId != nil &&
                    notification.taskAvailable != false &&
                    notification.isCheckIn != true {
                    Spacer().frame(height: 8)
                    Button(action: onCannotDo) {
                        Text("I cannot do this")
                            .font(appFont(13, .semibold))
                            .foregroundStyle(DangerRed)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .roundedBorder(DangerRed, 1, radius: 50)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)
                    Text("Keeps the task unresolved. High and critical reminders request a check-in from your selected contacts.")
                        .font(appFont(11))
                        .foregroundStyle(TextGray)
                }
            } else {
                Text("✓ Completed")
                    .font(appFont(15, .bold))
                    .foregroundStyle(TextGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0xDDDDDD))
                    .rounded(50)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .rounded(16)
    }
}

private struct NotificationTaskSheet: View {
    let taskId: String
    let onDismiss: () -> Void
    @State private var task: TaskItem?
    @State private var errorMessage: String?
    @State private var busy = false
    @State private var hiddenFromFamily = false

    var body: some View {
        NavigationStack {
            Group {
                if let task {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(task.displayName).font(appFont(22, .bold))
                            if let description = task.description?.nonBlank {
                                Text(description).font(appFont(15)).foregroundStyle(TextGray)
                            }
                            Text("Status: \(task.statusText)").font(appFont(15, .semibold))
                            if let date = task.startDatetime {
                                Text(formatNotificationTime(date)).font(appFont(14))
                            }
                            if TokenManager.isSenior() &&
                                (task.subjectUserId == nil || task.subjectUserId == TokenManager.getUserId()) {
                                Toggle("Hide from family", isOn: Binding(
                                    get: { hiddenFromFamily },
                                    set: { updateVisibility($0) }))
                                    .disabled(busy)
                            }
                            if task.canComplete == true &&
                                !["done", "completed", "skipped", "cancelled", "canceled"]
                                    .contains((task.status ?? task.taskStatusId ?? "").lowercased()) {
                                Button("Mark completed") { updateStatus(skip: false) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppGreen)
                                    .disabled(busy)
                                Button("Skip this task") { updateStatus(skip: true) }
                                    .buttonStyle(.bordered)
                                    .disabled(busy)
                            }
                            if let errorMessage {
                                Text(errorMessage).font(appFont(13)).foregroundStyle(DangerRed)
                            }
                        }
                        .padding(20)
                    }
                } else if let errorMessage {
                    ErrorRetry(message: errorMessage) { load() }
                } else {
                    ProgressView("Loading task...")
                }
            }
            .navigationTitle("Reminder")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .task { load() }
    }

    private func load() {
        guard !taskId.isBlank else { return }
        Task {
            await AppRepository.getTask(taskId: taskId).fold(
                onSuccess: {
                    task = $0
                    hiddenFromFamily = $0.hiddenFromFamily == true
                },
                onFailure: { errorMessage = $0.message })
        }
    }

    private func updateStatus(skip: Bool) {
        busy = true
        Task {
            let result = skip
                ? await AppRepository.skipTask(taskId: taskId)
                : await AppRepository.completeTask(taskId: taskId)
            await result.fold(
                onSuccess: { _ in
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    onDismiss()
                },
                onFailure: { errorMessage = $0.message })
            busy = false
        }
    }

    private func updateVisibility(_ hidden: Bool) {
        busy = true
        Task {
            await AppRepository.setTaskFamilyVisibility(taskId: taskId, hidden: hidden)
                .onSuccess { _ in
                    hiddenFromFamily = hidden
                    NotificationEventBus.shared.triggerScheduleRefresh()
                }
                .onFailure { errorMessage = $0.message }
            busy = false
        }
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
