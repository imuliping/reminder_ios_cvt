//
//  ResetView.swift
//  Port of shared/ResetScreen.kt.
//

import SwiftUI

struct ResetView: View {

    let onBack: () -> Void
    @StateObject private var vm = ResetViewModel()

    @State private var showResetNotifConfirm = false
    @State private var showResetDisplayConfirm = false
    @State private var showResetAllConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "Reset", onBack: onBack)

                if vm.isLoading {
                    ProgressView().progressViewStyle(.linear).tint(AppGreen)
                }

                if let errorMsg = vm.errorMsg {
                    Text(errorMsg)
                        .font(appFont(13))
                        .foregroundStyle(DangerRed)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: 0xFFEBEE))
                        .rounded(12)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                Spacer().frame(height: 16)

                // ── Partial Reset ─────────────────────────────────
                sectionLabel("Partial Reset")
                card {
                    resetRow(icon: "bell.slash.fill", iconBg: Color(hex: 0xE8EAF6),
                             iconTint: Color(hex: 0x3F51B5),
                             title: "Reset notification preferences",
                             subtitle: "Restore default alert settings",
                             buttonColor: Color(hex: 0xFF9800)) { showResetNotifConfirm = true }
                    Divider().background(Color(hex: 0xF0F0F0))
                    resetRow(icon: "textformat.size", iconBg: Color(hex: 0xE8F5E9),
                             iconTint: AppGreen,
                             title: "Reset display settings",
                             subtitle: "Font size, display mode, speech",
                             buttonColor: Color(hex: 0xFF9800)) { showResetDisplayConfirm = true }
                }

                Spacer().frame(height: 20)

                // ── Full Reset ────────────────────────────────────
                sectionLabel("Full Reset")
                card {
                    resetRow(icon: "arrow.counterclockwise.circle.fill", iconBg: Color(hex: 0xEDE7F6),
                             iconTint: Color(hex: 0x7E57C2),
                             title: "Reset all settings",
                             subtitle: "Restore factory defaults",
                             buttonColor: DangerRed) { showResetAllConfirm = true }
                }

                Spacer().frame(height: 16)

                // ── Warning banner ────────────────────────────────
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color(hex: 0xF57F17))
                    Text("Full reset requires password confirmation and cannot be reversed.")
                        .font(appFont(13))
                        .foregroundStyle(Color(hex: 0xF57F17))
                    Spacer()
                }
                .padding(16)
                .background(Color(hex: 0xFFF8E1))
                .rounded(14)
                .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                MessageEldaBar {}
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)
            }
        }
        .background(Color(hex: 0xF7F7F7))
        .alert("Reset notification preferences?", isPresented: $showResetNotifConfirm) {
            Button("Reset") { vm.resetNotificationPreferences {} }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all notification settings to their default values.")
        }
        .alert("Reset display settings?", isPresented: $showResetDisplayConfirm) {
            Button("Reset") { vm.resetDisplaySettings {} }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore font size, display mode, and speech settings to their defaults.")
        }
        .alert("Reset all settings?", isPresented: $showResetAllConfirm) {
            Button("Reset All", role: .destructive) { vm.resetAllSettings { onBack() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all your preferences to factory defaults. This cannot be undone.")
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(appFont(12, .medium))
                .foregroundStyle(TextGray)
                .tracking(0.8)
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

    private func resetRow(icon: String, iconBg: Color, iconTint: Color,
                          title: String, subtitle: String, buttonColor: Color,
                          onClick: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: icon).font(.system(size: 18)).foregroundStyle(iconTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(appFont(15, .medium)).foregroundStyle(TextDark)
                    Text(subtitle).font(appFont(12)).foregroundStyle(TextGray)
                }
            }
            .padding(.trailing, 12)
            Spacer()
            Button(action: onClick) {
                Text("reset")
                    .font(appFont(13, .semibold))
                    .foregroundStyle(buttonColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .roundedBorder(buttonColor, 1.5, radius: 50)
            }
            .buttonStyle(.plain)
            .disabled(vm.isLoading)
        }
        .padding(.vertical, 14)
    }
}
