//
//  Theme.swift
//  Port of shared/SharedComponents.kt colour constants, ui/theme/* and
//  shared/AppFontSize.kt.
//

import SwiftUI
import Combine

// ── Colors (SharedComponents.kt) ──────────────────────────────────
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

let AppGreen    = Color(hex: 0x7BAE8E)
let AppBg       = Color(hex: 0xF5F5F0)
let CardBg      = Color(hex: 0xF0F0EC)
let TextDark    = Color(hex: 0x1A1A1A)
let TextGray    = Color(hex: 0x888888)
let BorderGray  = Color(hex: 0xD0D0D0)
let GreenButton = Color(hex: 0x7BAE8E)
let BrownTitle  = Color(hex: 0x8B5E3C)
let FieldBg     = Color.white
let PageBg      = Color(hex: 0xF0EFEB)
let HintGray    = Color(hex: 0x9E9E9E)

// Frequently reused one-off colours from the Compose source
let DangerRed   = Color(hex: 0xE53935)
let WarnAmber   = Color(hex: 0xFFC107)
let PendingGold = Color(hex: 0xF57F17)
let CancelPink  = Color(hex: 0xF48FB1)
let SaveGray    = Color(hex: 0xDDDDDD)
let FieldFill   = Color(hex: 0xF0F0F0)

// ── Font scale (AppFontSize.kt) ───────────────────────────────────
/// Compose scaled the whole theme via LocalDensity(fontScale = …). SwiftUI has no
/// equivalent knob for fixed-size fonts, so the scale is applied through
/// `appFont(_:_:)`, and the root view observes this object so a change re-renders
/// the tree.
final class AppFontSize: ObservableObject {
    static let shared = AppFontSize()

    /// "small" | "medium" | "large" | "xlarge" (the settings screen also writes "extra_large")
    @Published var current: String = TokenManager.getFontSize() ?? "medium"

    private init() {}

    func set(_ size: String) {
        current = size
        TokenManager.saveFontSize(size)
    }

    var scale: CGFloat {
        switch current {
        case "small":                 return 0.85
        case "medium":                return 1.0
        case "large":                 return 1.15
        case "xlarge", "extra_large": return 1.3
        default:                      return 1.0
        }
    }
}

/// Every explicit font size in the port goes through this so the font-size
/// preference still applies app-wide.
func appFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size * AppFontSize.shared.scale, weight: weight)
}

// ── View helpers that keep the Compose-flavoured call sites readable ──
extension View {
    /// Compose's `Modifier.clip(RoundedCornerShape(n))`
    func rounded(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Compose's `Modifier.border(w, color, RoundedCornerShape(n))`
    func roundedBorder(_ color: Color, _ width: CGFloat = 1, radius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(color, lineWidth: width)
        )
    }

    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

/// The rounded grey text field used by almost every dialog in the Android app.
struct FilledFieldStyle: ViewModifier {
    var radius: CGFloat = 50
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FieldFill)
            .rounded(radius)
    }
}

extension View {
    func filledField(radius: CGFloat = 50) -> some View {
        modifier(FilledFieldStyle(radius: radius))
    }

    /// The white/bordered field used on the login + signup screens.
    func outlinedField() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FieldBg)
            .rounded(50)
            .roundedBorder(BorderGray, 1, radius: 50)
    }
}
