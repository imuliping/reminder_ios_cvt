//
//  GeneralSettingsView.swift
//  Port of shared/GeneralSettingsScreen.kt.
//

import SwiftUI

private let FONT_OPTIONS = ["small", "medium", "large", "extra_large"]
private let FONT_LABELS  = ["S", "M", "L", "XL"]

private let LANGUAGES = [
    "English (US)", "English (UK)", "French", "Spanish",
    "Portuguese", "Arabic", "Chinese (Simplified)", "Japanese"
]

struct GeneralSettingsView: View {

    let onBack: () -> Void
    var onNavigate: (String) -> Void = { _ in }
    @StateObject private var vm = GeneralSettingsViewModel()
    @ObservedObject private var fontSize = AppFontSize.shared

    @State private var interfaceMode = "detail"
    @State private var selectedFont = AppFontSize.shared.current
    @State private var selectedLang = TokenManager.getLanguage() ?? "English (US)"
    @State private var showLangPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "General", onBack: onBack)

                Spacer().frame(height: 24)

                // ── Interface Mode ────────────────────────────────
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: 0xE8F0FF))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: 0x3B7FC4))
                        )

                    interfaceModeCard(label: "Detail", subtitle: "Icons + text",
                                      icon: "square.grid.2x2.fill",
                                      selected: interfaceMode == "detail") {
                        interfaceMode = "detail"
                        vm.updateAccessibility { ux in
                            var copy = ux; copy.interfaceMode = "detail"; return copy
                        }
                    }

                    interfaceModeCard(label: "Simple", subtitle: "Icons only",
                                      icon: "square.grid.3x3.fill",
                                      selected: interfaceMode == "simple") {
                        interfaceMode = "simple"
                        vm.updateAccessibility { ux in
                            var copy = ux; copy.interfaceMode = "simple"; return copy
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)
                Divider().background(Color(hex: 0xEEEEEE)).padding(.horizontal, 16)
                Spacer().frame(height: 16)

                // ── Font Size ─────────────────────────────────────
                HStack {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0xF0F0F0))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "textformat.size")
                                    .font(.system(size: 19))
                                    .foregroundStyle(AppGreen)
                            )
                        Text("Font size").font(appFont(16, .medium)).foregroundStyle(TextDark)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(FONT_OPTIONS.indices, id: \.self) { index in
                            let option = FONT_OPTIONS[index]
                            let isSelected = selectedFont == option
                            Button {
                                selectedFont = option
                                // Font size is UI-only — not sent to the backend.
                                AppFontSize.shared.set(option)
                            } label: {
                                Text(FONT_LABELS[index])
                                    .font(appFont(14, isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .white : TextGray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? AppGreen : Color.white)
                                    .rounded(50)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .roundedBorder(Color(hex: 0xDDDDDD), 1, radius: 50)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)
                Divider().background(Color(hex: 0xEEEEEE)).padding(.horizontal, 16)
                Spacer().frame(height: 16)

                // ── Language ──────────────────────────────────────
                Button { showLangPicker = true } label: {
                    HStack {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: 0xF0E8FF))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "globe")
                                        .font(.system(size: 19))
                                        .foregroundStyle(Color(hex: 0x6B4EFF))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Language").font(appFont(16, .medium)).foregroundStyle(TextDark)
                                Text(selectedLang).font(appFont(13)).foregroundStyle(TextGray)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(TextGray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 32)

                if let message = vm.saveState.errorMessage {
                    Text(message)
                        .font(appFont(13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                    Spacer().frame(height: 8)
                }

                Button {
                    TokenManager.saveLanguage(selectedLang)
                    vm.save()
                } label: {
                    ZStack {
                        if vm.saveState.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save").font(appFont(16, .semibold)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppGreen)
                    .rounded(50)
                }
                .buttonStyle(.plain)
                .disabled(vm.saveState.isLoading)
                .padding(.horizontal, 16)

                Spacer().frame(height: 24)

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
        .onChange(of: vm.settingsState.isSuccess) { _, _ in
            if let settings = vm.settingsState.data {
                interfaceMode = settings.accessibilityUx?.interfaceMode ?? "detail"
            }
        }
        .sheet(isPresented: $showLangPicker) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select Language").font(appFont(18, .bold)).padding(.bottom, 16)
                ForEach(LANGUAGES, id: \.self) { lang in
                    Button {
                        selectedLang = lang
                        showLangPicker = false
                    } label: {
                        HStack {
                            Text(lang).font(appFont(15)).foregroundStyle(TextDark)
                            Spacer()
                            if lang == selectedLang {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16)).foregroundStyle(AppGreen)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if lang != LANGUAGES.last {
                        Divider().background(Color(hex: 0xF0F0F0))
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func interfaceModeCard(label: String, subtitle: String, icon: String,
                                   selected: Bool, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(selected ? AppGreen : TextGray)
                Text(label)
                    .font(appFont(14, .semibold))
                    .foregroundStyle(selected ? AppGreen : TextDark)
                Text(subtitle)
                    .font(appFont(12))
                    .foregroundStyle(TextGray)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(selected ? Color(hex: 0xF0F7F4) : Color.white)
            .rounded(16)
            .roundedBorder(selected ? AppGreen : Color(hex: 0xDDDDDD), selected ? 2 : 1, radius: 16)
        }
        .buttonStyle(.plain)
    }
}
