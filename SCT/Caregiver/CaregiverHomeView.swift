//
//  CaregiverHomeView.swift
//  Port of caregiver/CaregiverHomeScreen.kt.
//

import SwiftUI

struct CaregiverHomeView: View {

    let onNavigate: (String) -> Void
    let onReportClick: () -> Void
    let onShopListClick: () -> Void
    let onAvailableTimeClick: () -> Void
    let onNotificationClick: () -> Void
    let onProfileClick: () -> Void
    @StateObject private var vm = CaregiverHomeViewModel()

    @State private var showSupportDialog = false

    private var caregiverName: String { (TokenManager.getUsername() ?? "User").capitalizedFirst }
    private var seniorName: String { TokenManager.getSeniorName() }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────
                    HStack {
                        Button(action: onProfileClick) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: 0xE0E0E0))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color(hex: 0x888888))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 0) {
                                        Text(caregiverName).font(appFont(15, .bold)).foregroundStyle(TextDark)
                                        Text(" (User)").font(appFont(15)).foregroundStyle(TextGray)
                                    }
                                    HStack(spacing: 0) {
                                        Text(seniorName).font(appFont(13, .medium)).foregroundStyle(TextDark)
                                        Text(" (Senior)").font(appFont(13)).foregroundStyle(TextGray)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button(action: onNotificationClick) {
                            Image(systemName: "bell")
                                .font(.system(size: 24))
                                .foregroundStyle(TextDark)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    // ── Coming up card ────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Coming up").font(appFont(15, .bold)).foregroundStyle(TextDark)
                            Spacer()
                            Text("Next 7 days").font(appFont(12)).foregroundStyle(TextGray)
                        }
                        Spacer().frame(height: 12)

                        switch vm.tasksState {
                        case .loading:
                            ProgressView().tint(AppGreen).frame(maxWidth: .infinity)
                        case .success(let tasks):
                            if tasks.isEmpty {
                                Text("No upcoming tasks this week")
                                    .font(appFont(14)).foregroundStyle(TextGray)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(tasks) { task in
                                    CaregiverUpcomingTaskRow(task: task,
                                                             isAssigned: vm.offersMap[task.taskId] != nil)
                                    Spacer().frame(height: 10)
                                }
                            }
                        case .error:
                            Text("Could not load tasks").font(appFont(13)).foregroundStyle(.red)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xF5F5F5))
                    .rounded(16)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 16)

                    // ── Pending Offers card ───────────────────────
                    Button { onNavigate("caregiver_offers_for_me") } label: {
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(vm.offersForMe.isEmpty ? TextGray : Color(hex: 0xB8860B))
                                Text(vm.offersForMe.isEmpty ? "No pending offers" : "Pending Offers")
                                    .font(appFont(15, .bold))
                                    .foregroundStyle(TextDark)
                                if !vm.offersForMe.isEmpty {
                                    Text("\(vm.offersForMe.count)")
                                        .font(appFont(11, .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(DangerRed)
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(TextGray)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(vm.offersForMe.isEmpty ? Color(hex: 0xF5F5F5) : Color(hex: 0xFFF8E1))
                        .rounded(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)

                    Text("What care tasks need your\nattention today?")
                        .font(appFont(17, .bold))
                        .foregroundStyle(TextDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    HStack(spacing: 12) {
                        VStack(spacing: 12) {
                            CaregiverActionCard(icon: "list.clipboard.fill", label: "report",
                                                height: 110, action: onReportClick)
                            CaregiverActionCard(icon: "cart.fill", label: "shop list",
                                                height: 110, action: onShopListClick)
                        }
                        Button(action: onAvailableTimeClick) {
                            VStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 34))
                                    .foregroundStyle(TextDark)
                                Text("available").font(appFont(14)).foregroundStyle(TextDark)
                                Text("time").font(appFont(14)).foregroundStyle(TextDark)
                            }
                            .frame(maxWidth: .infinity, minHeight: 232)
                            .background(Color(hex: 0xF5F5F5))
                            .rounded(16)
                            .roundedBorder(Color(hex: 0xCCCCCC), 1.5, radius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    MessageEldaBar { onNavigate("caregiver_aichat/caregiver_home") }
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 8)

                    ContactSupportButton(showSheet: $showSupportDialog)
                        .padding(.bottom, 8)
                }
            }
            .background(Color.white)

            CaregiverBottomNavBar(current: "home", onNavigate: onNavigate)
        }
        .sheet(isPresented: $showSupportDialog) {
            SupportLogSheet(
                title: "Contact Support",
                explanation: "Send us your debug log and we'll look into the issue.",
                confirmLabel: "Send Log",
                isPresented: $showSupportDialog
            )
        }
    }
}

// ── Upcoming task row ─────────────────────────────────────────────

struct CaregiverUpcomingTaskRow: View {

    let task: TaskItem
    let isAssigned: Bool

    var body: some View {
        let dateBox = formatDateBox(task.startDatetime ?? "")
        let timeStr = formatTimeOnly(task.startDatetime ?? "")

        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text(dateBox.0).font(appFont(22, .bold)).foregroundStyle(TextDark)
                Text(dateBox.1).font(appFont(12, .medium)).foregroundStyle(TextGray)
            }
            .frame(width: 56)

            Spacer().frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayName)
                    .font(appFont(15, .bold))
                    .foregroundStyle(TextDark)
                    .underline()
                if !timeStr.isEmpty {
                    Text(timeStr).font(appFont(13)).foregroundStyle(TextGray)
                }
            }

            Spacer()

            // Assignment badge — only shown when assigned
            if isAssigned {
                Text("✓ Assigned")
                    .font(appFont(11, .semibold))
                    .foregroundStyle(Color(hex: 0x2E7D32))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: 0xE8F5E9))
                    .rounded(50)
            }
        }
    }
}

// ── Action card ───────────────────────────────────────────────────

struct CaregiverActionCard: View {
    let icon: String
    let label: String
    var height: CGFloat = 110
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(TextDark)
                Text(label).font(appFont(14)).foregroundStyle(TextDark)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color(hex: 0xF5F5F5))
            .rounded(16)
            .roundedBorder(Color(hex: 0xCCCCCC), 1.5, radius: 16)
        }
        .buttonStyle(.plain)
    }
}
