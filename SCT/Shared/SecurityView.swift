//
//  SecurityView.swift
//  Port of shared/SecurityScreen.kt.
//

import SwiftUI

struct SecurityView: View {

    let onBack: () -> Void
    @StateObject private var vm = SecurityViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "Security", onBack: onBack)

                Spacer().frame(height: 16)

                switch vm.settingsState {
                case .loading:
                    ProgressView().tint(AppGreen).padding(48)

                case .error(let message):
                    ErrorRetry(message: message) { vm.loadSettings() }

                case .success(let settings):
                    let security = settings.accountSecurity ?? AccountSecurity()

                    // ── Login ─────────────────────────────────────
                    sectionLabel("Login")
                    card {
                        HStack {
                            HStack(spacing: 14) {
                                iconBox("touchid", Color(hex: 0xE8EAF6), Color(hex: 0x3F51B5))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Biometric login")
                                        .font(appFont(15, .medium)).foregroundStyle(TextDark)
                                    Text("Face ID / Fingerprint")
                                        .font(appFont(12)).foregroundStyle(TextGray)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { security.biometricLogin ?? false },
                                set: { value in
                                    vm.updateAccountSecurity { current in
                                        var copy = current
                                        copy.biometricLogin = value
                                        return copy
                                    }
                                    vm.save()
                                }
                            ))
                            .labelsHidden()
                            .tint(AppGreen)
                        }
                        .padding(.vertical, 12)

                        Divider().background(Color(hex: 0xF0F0F0))

                        navRow(icon: "lock.fill", iconBg: Color(hex: 0xE8F5E9), iconTint: AppGreen,
                               label: "Change password") { /* TODO: change password flow */ }
                    }

                    AutoLogoutSettingsView()

                    Spacer().frame(height: 20)

                    // ── Legal ─────────────────────────────────────
                    sectionLabel("Legal")
                    card {
                        navRow(icon: "doc.text.fill", iconBg: Color(hex: 0xE3F2FD),
                               iconTint: Color(hex: 0x1E88E5), label: "Terms of use") { }
                        Divider().background(Color(hex: 0xF0F0F0))
                        navRow(icon: "shield.fill", iconBg: Color(hex: 0xFFF8E1),
                               iconTint: Color(hex: 0xFFC107), label: "Privacy policy") { }
                        Divider().background(Color(hex: 0xF0F0F0))
                        navRow(icon: "info.circle.fill", iconBg: Color(hex: 0xEDE7F6),
                               iconTint: Color(hex: 0x7E57C2), label: "Disclaimer",
                               subtitle: "Local laws & user consent") { }
                    }

                    Spacer().frame(height: 20)

                    // ── Account ───────────────────────────────────
                    sectionLabel("Account")
                    card {
                        navRow(icon: "trash", iconBg: Color(hex: 0xFFEBEE), iconTint: DangerRed,
                               label: "Delete account",
                               subtitle: "Permanent, cannot be undone",
                               labelColor: DangerRed) { /* TODO: confirm + delete */ }
                    }

                    Spacer().frame(height: 24)

                default:
                    EmptyView()
                }
            }
        }
        .background(Color(hex: 0xF7F7F7))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color.white)
            .rounded(14)
            .padding(.horizontal, 16)
    }

    private func iconBox(_ icon: String, _ bg: Color, _ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(bg)
            .frame(width: 36, height: 36)
            .overlay(Image(systemName: icon).font(.system(size: 17)).foregroundStyle(tint))
    }

    private func navRow(icon: String, iconBg: Color, iconTint: Color, label: String,
                        subtitle: String? = nil, labelColor: Color = TextDark,
                        onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            HStack {
                HStack(spacing: 14) {
                    iconBox(icon, iconBg, iconTint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(appFont(15, .medium)).foregroundStyle(labelColor)
                        if let subtitle, subtitle.isNotBlank {
                            Text(subtitle).font(appFont(12)).foregroundStyle(TextGray)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xCCCCCC))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
