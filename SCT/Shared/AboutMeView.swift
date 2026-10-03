//
//  AboutMeView.swift
//  Port of shared/AboutMeScreen.kt.
//

import SwiftUI

struct AboutMeView: View {

    let onBack: () -> Void
    let onLogout: () -> Void
    var onNavigate: (String) -> Void = { _ in }

    @State private var showSupportDialog = false

    private var displayName: String { (TokenManager.getUsername() ?? "User").capitalizedFirst }
    private var role: String { (TokenManager.getRoleId() ?? "").capitalizedFirst }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "About Me", onBack: onBack)

                Spacer().frame(height: 20)

                // ── Avatar + name ─────────────────────────────────
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color(hex: 0xE8F5E9))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AppGreen)
                        )
                    Spacer().frame(height: 10)
                    Text(displayName).font(appFont(20, .bold)).foregroundStyle(TextDark)
                    if role.isNotBlank {
                        Spacer().frame(height: 2)
                        Text(role).font(appFont(13, .medium)).foregroundStyle(AppGreen)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 24)

                // ── Account section ───────────────────────────────
                sectionLabel("Account")
                card {
                    row(icon: "person.fill", iconBg: Color(hex: 0xE8F5E9), iconTint: AppGreen,
                        label: "Profile") { onNavigate("profile_detail") }
                    rowDivider
                    row(icon: "person.2.fill", iconBg: Color(hex: 0xFFF3E0), iconTint: Color(hex: 0xFF9800),
                        label: "Relative accounts") { onNavigate("relative_accounts") }
                    rowDivider
                    row(icon: "gift.fill", iconBg: Color(hex: 0xE8F5E9), iconTint: AppGreen,
                        label: "Join family account") { onNavigate("accept_invite") }
                }

                Spacer().frame(height: 20)

                // ── Preferences section ───────────────────────────
                sectionLabel("Preferences")
                card {
                    row(icon: "gearshape.fill", iconBg: Color(hex: 0xE8EAF6), iconTint: Color(hex: 0x3F51B5),
                        label: "General settings") { onNavigate("general_settings") }
                    rowDivider
                    row(icon: "bell.fill", iconBg: Color(hex: 0xFFF8E1), iconTint: Color(hex: 0xFFC107),
                        label: "Notification settings") { onNavigate("notification_settings") }
                    rowDivider
                    row(icon: "lock.shield.fill", iconBg: Color(hex: 0xFFEBEE), iconTint: DangerRed,
                        label: "Security") { onNavigate("security") }
                    rowDivider
                    row(icon: "arrow.clockwise", iconBg: Color(hex: 0xEDE7F6), iconTint: Color(hex: 0x7E57C2),
                        label: "Reset settings") { onNavigate("reset_settings") }
                }

                Spacer().frame(height: 32)

                // ── Log out ───────────────────────────────────────
                Button {
                    AppRepository.logout()
                    onLogout()
                } label: {
                    Text("Log out")
                        .font(appFont(16, .semibold))
                        .foregroundStyle(DangerRed)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color(hex: 0xFFF0EE))
                        .rounded(50)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)

                ContactSupportButton(label: "Send debug log", showSheet: $showSupportDialog)

                Spacer().frame(height: 20)

                MessageEldaBar {
                    if TokenManager.isCaregiver() { onNavigate("caregiver_aichat") }
                    else if TokenManager.isFamilyMember() { onNavigate("family_aichat") }
                    else { onNavigate("aichat") }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 16)
            }
        }
        .background(Color(hex: 0xF7F7F7))
        .sheet(isPresented: $showSupportDialog) {
            SupportLogSheet(
                title: "Send Debug Log",
                explanation: "The debug log will be emailed with details about what went wrong.",
                confirmLabel: "Send",
                isPresented: $showSupportDialog
            )
        }
    }

    // ── Sub-views ─────────────────────────────────────────────────

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(appFont(13, .medium)).foregroundStyle(TextGray)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white)
            .rounded(14)
            .padding(.horizontal, 16)
    }

    private func row(icon: String, iconBg: Color, iconTint: Color,
                     label: String, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            HStack {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBg)
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: icon).font(.system(size: 17)).foregroundStyle(iconTint))
                    Text(label).font(appFont(16, .medium)).foregroundStyle(TextDark)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xCCCCCC))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Divider()
            .background(Color(hex: 0xF0F0F0))
            .padding(.leading, 66)
    }
}
