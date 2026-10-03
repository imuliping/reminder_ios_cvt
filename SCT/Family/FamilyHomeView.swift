//
//  FamilyHomeView.swift
//  Port of family/FamilyHomeScreen.kt.
//

import SwiftUI

struct FamilyHomeView: View {

    let onNavigate: (String) -> Void
    let onScheduleClick: () -> Void
    let onShopListClick: () -> Void
    let onNotificationClick: () -> Void
    let onProfileClick: () -> Void
    @StateObject private var vm = FamilyHomeViewModel()

    @State private var showSupportDialog = false

    private var familyUsername: String { (TokenManager.getUsername() ?? "User").capitalizedFirst }
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
                                        Text(familyUsername).font(appFont(15, .bold)).foregroundStyle(TextDark)
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
                    Button(action: onScheduleClick) {
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
                                        let offer = vm.offersMap[task.taskId]
                                        UpcomingTaskRow(task: task, isAssigned: offer != nil, offer: offer)
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
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 12)

                    // ── Offers For Me banner ──────────────────────
                    Button { onNavigate("family_offers_for_me") } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                HStack(spacing: 8) {
                                    Text("Offers For Me").font(appFont(15, .bold)).foregroundStyle(TextDark)
                                    if !vm.offersForMe.isEmpty {
                                        Text("\(vm.offersForMe.count)")
                                            .font(appFont(11, .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .background(PendingGold)
                                            .clipShape(Circle())
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(TextGray)
                            }

                            Spacer().frame(height: 10)

                            if vm.offersForMe.isEmpty {
                                Text("No pending offers").font(appFont(14)).foregroundStyle(TextGray)
                            } else {
                                ForEach(vm.offersForMe) { offer in
                                    HStack {
                                        Text(offer.message?
                                            .replacingOccurrences(of: "You've been assigned: ", with: "")
                                            .nonBlank ?? "Task offer")
                                            .font(appFont(14, .medium))
                                            .foregroundStyle(TextDark)
                                        Spacer()
                                        Text("Pending")
                                            .font(appFont(11, .semibold))
                                            .foregroundStyle(PendingGold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: 0xFFF8E1))
                                            .rounded(50)
                                            .roundedBorder(PendingGold, 1, radius: 50)
                                    }
                                    .padding(.vertical, 4)
                                }
                                Spacer().frame(height: 4)
                                Text("Tap to accept or decline →")
                                    .font(appFont(12)).foregroundStyle(TextGray)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(vm.offersForMe.isEmpty ? Color(hex: 0xF5F5F5) : Color(hex: 0xFFF8E1))
                        .rounded(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)

                    Text("How can I help you manage your\nloved one's day ?")
                        .font(appFont(17, .bold))
                        .foregroundStyle(TextDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    // ── Action cards grid ─────────────────────────
                    HStack(spacing: 12) {
                        VStack(spacing: 12) {
                            FamilyActionCard(icon: "list.clipboard.fill", label: "report") {
                                onNavigate("family_report")
                            }
                            FamilyActionCard(icon: "cart.fill", label: "shop list", action: onShopListClick)
                        }
                        VStack(spacing: 12) {
                            FamilyActionCard(icon: "calendar", label: "Supervise") {
                                onNavigate("supervise")
                            }
                            FamilyActionCard(icon: "tray.fill", label: "offers assigned", labelSize: 13) {
                                onNavigate("family_offers_assigned")
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    MessageEldaBar { onNavigate("family_aichat/family_home") }
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 8)

                    ContactSupportButton(showSheet: $showSupportDialog)
                        .padding(.bottom, 8)
                }
            }
            .background(Color.white)

            FamilyBottomNavBar(current: "home", onNavigate: onNavigate)
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

struct UpcomingTaskRow: View {

    let task: TaskItem
    let isAssigned: Bool
    var offer: TaskAssignmentOffer?

    var body: some View {
        let dateBox = formatDateBox(task.startDatetime ?? "")
        let timeStr = formatTimeOnly(task.startDatetime ?? "")
        let offerStatus = offer?.status?.uppercased()

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
                if timeStr.isNotEmpty {
                    Text(timeStr).font(appFont(13)).foregroundStyle(TextGray)
                }
            }

            Spacer()

            if isAssigned {
                let info: (String, Color, Color) = {
                    switch offerStatus {
                    case "ACCEPTED": return ("✓ Accepted", Color(hex: 0xE8F5E9), Color(hex: 0x2E7D32))
                    case "DECLINED": return ("✗ Declined", Color(hex: 0xFFEBEE), DangerRed)
                    default:         return ("Pending",    Color(hex: 0xFFF8E1), PendingGold)
                    }
                }()
                Text(info.0)
                    .font(appFont(11, .semibold))
                    .foregroundStyle(info.2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(info.1)
                    .rounded(50)
            }
        }
    }
}

// ── Action card ───────────────────────────────────────────────────

struct FamilyActionCard: View {
    let icon: String
    let label: String
    var labelSize: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(TextDark)
                Text(label).font(appFont(labelSize)).foregroundStyle(TextDark)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(Color(hex: 0xF5F5F5))
            .rounded(16)
            .roundedBorder(Color(hex: 0xCCCCCC), 1.5, radius: 16)
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
