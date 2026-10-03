//
//  NotificationSettingsView.swift
//  Port of shared/NotificationSettingScreen.kt.
//

import SwiftUI

struct NotificationSettingsView: View {

    let onBack: () -> Void
    var onNavigate: (String) -> Void = { _ in }
    @StateObject private var vm = NotificationSettingsViewModel()

    // Device-level toggles stored locally (not in the backend policy), exactly
    // as the Android screen did with `remember { mutableStateOf(...) }`.
    @State private var inApp = true
    @State private var sms = false
    @State private var email = false
    @State private var vibration = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "Notifications", onBack: onBack)

                Spacer().frame(height: 20)

                // ── Alert Type ────────────────────────────────────
                sectionLabel("ALERT TYPE")
                card {
                    toggleRow(icon: "iphone", iconBg: Color(hex: 0xE8F0FF), iconTint: Color(hex: 0x3B7FC4),
                              label: "In-app notification", isOn: $inApp)
                    divider
                    toggleRow(icon: "message.fill", iconBg: Color(hex: 0xE8FFE8), iconTint: Color(hex: 0x2E7D32),
                              label: "SMS", isOn: $sms)
                    divider
                    toggleRow(icon: "envelope.fill", iconBg: Color(hex: 0xFFF3E0), iconTint: Color(hex: 0xE65100),
                              label: "Email", isOn: $email)
                    divider
                    toggleRow(icon: "waveform", iconBg: Color(hex: 0xF3E8FF), iconTint: Color(hex: 0x6B4EFF),
                              label: "Vibration", isOn: $vibration)
                }

                Spacer().frame(height: 20)

                // ── Sound ─────────────────────────────────────────
                sectionLabel("SOUND")
                card {
                    navRow(icon: "bell.badge.fill", iconBg: Color(hex: 0xE8F5E9), iconTint: AppGreen,
                           label: "Regular reminder", subtitle: "Ringtone & volume")
                    divider
                    navRow(icon: "bell.badge.waveform.fill", iconBg: Color(hex: 0xFFF8E1),
                           iconTint: Color(hex: 0xFF8F00),
                           label: "Important reminder", subtitle: "Ringtone & volume")
                    divider
                    navRow(icon: "alarm.fill", iconBg: Color(hex: 0xFFEBEE), iconTint: DangerRed,
                           label: "Urgent — never miss", subtitle: "Overrides silent mode")
                }

                Spacer().frame(height: 20)

                // ── Follow-up Frequency (from backend policy) ─────
                sectionLabel("FOLLOW - UP FREQUENCY")
                followUpSection

                Spacer().frame(height: 20)

                CheckInSettingsView()

                Spacer().frame(height: 20)

                // ── Silent Hours ──────────────────────────────────
                sectionLabel("SILENT HOURS")
                card {
                    navRow(icon: "moon.fill", iconBg: Color(hex: 0xE8E8FF), iconTint: Color(hex: 0x3F51B5),
                           label: "Do not disturb", subtitle: "10:00 PM – 7:00 AM")
                    divider
                    toggleRow(icon: "sos", iconBg: Color(hex: 0xFFEBEE), iconTint: DangerRed,
                              label: "Emergency override", subtitle: "Always break through",
                              isOn: .constant(true))
                }

                Spacer().frame(height: 20)

                MessageEldaBar {
                    if TokenManager.isFamilyMember() { onNavigate("family_aichat") }
                    else if TokenManager.isCaregiver() { onNavigate("caregiver_aichat") }
                    else { onNavigate("aichat") }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 16)
            }
        }
        .background(Color(hex: 0xF7F7F7))
    }

    @ViewBuilder
    private var followUpSection: some View {
        switch vm.policiesState {
        case .loading:
            ProgressView().tint(AppGreen).padding(24)

        case .error:
            Button { vm.loadPolicies() } label: {
                Text("Retry").font(appFont(15)).foregroundStyle(AppGreen)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

        case .success(let policies):
            // Medicine & Health (priority level 3 = Standard / medication)
            let medPolicy = policies.first {
                $0.priorityLevelId == "90fd17af-70b1-51c1-a46d-d806db23787c"
                    || $0.priorityLevelId == "cd76228e-d0fd-55db-9bcf-7137672ec348"
            }
            FrequencyCard(
                icon: "heart.text.square.fill",
                iconBg: Color(hex: 0xE8F5E9), iconTint: AppGreen,
                title: "Medicine & Health",
                subtitle: "How often to re-remind if not done",
                options: [5, 10, 15],
                selectedMinutes: (medPolicy?.repeatIntervalSeconds ?? 600) / 60,
                onSelect: { minutes in
                    if let medPolicy { vm.setRepeatInterval(medPolicy, minutes * 60) }
                }
            )

            Spacer().frame(height: 12)

            // Daily routines (priority level 2 = Moderate)
            let routinePolicy = policies.first {
                $0.priorityLevelId == "5de8db07-0663-54fc-b6f1-c298070adf85"
            }
            FrequencyCard(
                icon: "list.bullet",
                iconBg: Color(hex: 0xF3E8FF), iconTint: Color(hex: 0x6B4EFF),
                title: "Daily routines",
                subtitle: "How often to re-remind if not done",
                options: [30, 60, 120],
                selectedMinutes: (routinePolicy?.repeatIntervalSeconds ?? 3600) / 60,
                onSelect: { minutes in
                    if let routinePolicy { vm.setRepeatInterval(routinePolicy, minutes * 60) }
                }
            )

            Spacer().frame(height: 12)

            // Urgent keep reminding notice
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(Color(hex: 0xE65100))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Urgent — keep reminding")
                        .font(appFont(14, .semibold))
                        .foregroundStyle(Color(hex: 0xBF360C))
                    Text("Urgent reminders will keep alerting until you confirm or dismiss them.")
                        .font(appFont(13))
                        .foregroundStyle(Color(hex: 0xBF360C))
                }
                Spacer()
            }
            .padding(16)
            .background(Color(hex: 0xFFF3E0))
            .rounded(14)
            .padding(.horizontal, 16)

        default:
            EmptyView()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(appFont(11, .bold))
                .foregroundStyle(TextGray)
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 16)
            .background(Color.white)
            .rounded(14)
            .padding(.horizontal, 16)
    }

    private var divider: some View {
        Divider().background(Color(hex: 0xF0F0F0))
    }

    private func iconBox(_ icon: String, _ bg: Color, _ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(bg)
            .frame(width: 36, height: 36)
            .overlay(Image(systemName: icon).font(.system(size: 17)).foregroundStyle(tint))
    }

    private func toggleRow(icon: String, iconBg: Color, iconTint: Color,
                           label: String, subtitle: String? = nil,
                           isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 12) {
                iconBox(icon, iconBg, iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(appFont(15)).foregroundStyle(TextDark)
                    if let subtitle, subtitle.isNotBlank {
                        Text(subtitle).font(appFont(12)).foregroundStyle(TextGray)
                    }
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(AppGreen)
        }
        .padding(.vertical, 12)
    }

    private func navRow(icon: String, iconBg: Color, iconTint: Color,
                        label: String, subtitle: String? = nil) -> some View {
        HStack {
            HStack(spacing: 12) {
                iconBox(icon, iconBg, iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(appFont(15)).foregroundStyle(TextDark)
                    if let subtitle, subtitle.isNotBlank {
                        Text(subtitle).font(appFont(12)).foregroundStyle(TextGray)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(TextGray)
        }
        .padding(.vertical, 12)
    }
}

// ─────────────────────────────────────────────────────────────────
//  FREQUENCY CARD
// ─────────────────────────────────────────────────────────────────

private struct FrequencyCard: View {
    let icon: String
    let iconBg: Color
    let iconTint: Color
    let title: String
    let subtitle: String
    let options: [Int]         // minutes
    let selectedMinutes: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).font(.system(size: 17)).foregroundStyle(iconTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(appFont(15, .semibold)).foregroundStyle(TextDark)
                    Text(subtitle).font(appFont(12)).foregroundStyle(TextGray)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { minutes in
                    let isSelected = minutes == selectedMinutes
                    Button { onSelect(minutes) } label: {
                        Text(minutes >= 60 ? "\(minutes / 60) hour" : "\(minutes) min")
                            .font(appFont(13, .medium))
                            .foregroundStyle(isSelected ? .white : TextDark)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? AppGreen : Color.white)
                            .rounded(50)
                            .roundedBorder(isSelected ? AppGreen : Color(hex: 0xDDDDDD), 1, radius: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .rounded(14)
        .padding(.horizontal, 16)
    }
}
