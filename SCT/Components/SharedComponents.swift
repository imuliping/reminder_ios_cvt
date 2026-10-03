//
//  SharedComponents.swift
//  Port of shared/SharedComponents.kt (BottomNavBar, MessageEldaBar),
//  shared/Offerhelpers.kt (OfferActionRow, OfferStatusText), and the small
//  reusable widgets that lived inside the senior screens — SectionHeader,
//  OverdueBadge, SDateBox, STimeBox, SRoundedField, SDialogField.
//

import SwiftUI

// ── Bottom Nav Bars ───────────────────────────────────────────────

/// Senior nav bar (SharedComponents.kt).
struct BottomNavBar: View {
    let current: String
    let onNavigate: (String) -> Void

    var body: some View {
        NavBarContainer {
            NavBarItem(icon: "rectangle.split.3x1.fill", label: "My Day",
                       selected: current == "myday") { onNavigate("myday") }
            NavBarItem(icon: "house.fill", label: "Home",
                       selected: current == "home") { onNavigate("home") }
            NavBarItem(icon: "bubble.left.fill", label: "Chat",
                       selected: current == "chat") { onNavigate("chat") }
        }
    }
}

/// Family nav bar (FamilyHomeScreen.kt).
struct FamilyBottomNavBar: View {
    let current: String
    let onNavigate: (String) -> Void

    var body: some View {
        NavBarContainer {
            NavBarItem(icon: "list.bullet", label: "Schedules",
                       selected: current == "schedules") { onNavigate("family_schedule") }
            NavBarItem(icon: "house.fill", label: "Home",
                       selected: current == "home") { onNavigate("family_home") }
            NavBarItem(icon: "bubble.left.fill", label: "Chat",
                       selected: current == "chat") { onNavigate("family_chat") }
        }
    }
}

/// Caregiver nav bar (CaregiverHomeScreen.kt).
struct CaregiverBottomNavBar: View {
    let current: String
    let onNavigate: (String) -> Void

    var body: some View {
        NavBarContainer {
            NavBarItem(icon: "list.bullet", label: "Schedules",
                       selected: current == "schedules") { onNavigate("caregiver_schedule") }
            NavBarItem(icon: "house.fill", label: "Home",
                       selected: current == "home") { onNavigate("caregiver_home") }
            NavBarItem(icon: "bubble.left.fill", label: "Chat",
                       selected: current == "chat") { onNavigate("caregiver_chat") }
        }
    }
}

private struct NavBarContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color(hex: 0xEEEEEE))
            HStack { content }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                .background(Color.white)
        }
    }
}

private struct NavBarItem: View {
    let icon: String
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(label).font(appFont(11))
            }
            .foregroundStyle(selected ? AppGreen : TextGray)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// ── Message Elda Bar ──────────────────────────────────────────────

struct MessageEldaBar: View {
    var placeholder: String = "Message Elda"
    var onClick: () -> Void = {}

    var body: some View {
        Button(action: onClick) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(TextGray)
                    Text(placeholder)
                        .font(appFont(16))
                        .foregroundStyle(TextGray)
                }
                Spacer()
                EldaAvatar(size: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: 0xEEEEEE))
            .rounded(50)
        }
        .buttonStyle(.plain)
    }
}

// ── Offer helpers (Offerhelpers.kt) ───────────────────────────────

struct OfferActionRow: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAccept) {
                Text("Accept")
                    .font(appFont(13, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(AppGreen)
                    .rounded(50)
            }
            .buttonStyle(.plain)

            Button(action: onDecline) {
                Text("Decline")
                    .font(appFont(13, .semibold))
                    .foregroundStyle(DangerRed)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .roundedBorder(DangerRed, 1, radius: 50)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }
}

struct OfferStatusText: View {
    let offer: TaskAssignmentOffer
    let isAssignedToMe: Bool

    var body: some View {
        let status = offer.status?.uppercased()
        let isPending  = status == "PENDING"
        let isAccepted = status == "ACCEPTED"
        let isDeclined = status == "DECLINED"

        let text: String = {
            if isAssignedToMe && isPending  { return "Assigned to you — pending" }
            if isAssignedToMe && isAccepted { return "Assigned to you — accepted" }
            if isAssignedToMe && isDeclined { return "Assigned to you — declined" }
            if isPending  { return "Assigned — pending response" }
            if isAccepted { return "Assigned — accepted ✓" }
            if isDeclined { return "Assigned — declined ✗" }
            return "Assigned"
        }()

        let color: Color = isAccepted ? AppGreen : (isDeclined ? DangerRed : WarnAmber)

        Text(text)
            .font(appFont(12, .medium))
            .foregroundStyle(color)
    }
}

// ── Section header with the circled "+" (ScheduleScreen.kt) ────────

struct SectionHeader: View {
    let title: String
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(appFont(22, .bold))
                .underline()
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TextDark)
                    .frame(width: 36, height: 36)
                    .roundedBorder(TextDark, 2, radius: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// ── Overdue badge (ScheduleScreen.kt) ─────────────────────────────

struct OverdueBadge: View {
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(DangerRed)
                .rounded(8)
        }
        .buttonStyle(.plain)
    }
}

/// The empty / checked / skipped / started status boxes used on task cards.
struct StatusBox: View {
    let indicator: StatusIndicator
    let onComplete: () -> Void

    var body: some View {
        switch indicator {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppGreen)
                .rounded(8)
        case .skipped:
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(hex: 0xCCCCCC))
                .rounded(8)
        case .started:
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: 0xFF9800))
                .frame(width: 34, height: 34)
                .background(Color(hex: 0xFFF3E0))
                .rounded(8)
        case .overdue:
            OverdueBadge(onClick: onComplete)
        case .pending:
            Button(action: onComplete) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .roundedBorder(Color(hex: 0xAAAAAA), 2, radius: 6)
            }
            .buttonStyle(.plain)
        }
    }
}

// ── Dialog field widgets (ScheduleScreen.kt) ───────────────────────

/// SDialogField — bold label, optional red asterisk, then the field.
struct SDialogField<Content: View>: View {
    let label: String
    var required: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(label).font(appFont(15, .bold))
                if required { Text("*").font(appFont(15)).foregroundStyle(DangerRed) }
                Text(":").font(appFont(15, .bold))
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// SRoundedField — the grey pill (single line) or rounded box (multi-line) field.
struct SRoundedField: View {
    @Binding var text: String
    var singleLine: Bool = true
    var minLines: Int = 1
    var maxLines: Int = 1
    var placeholder: String = ""

    var body: some View {
        if singleLine {
            TextField(placeholder, text: $text)
                .font(appFont(15))
                .textInputAutocapitalization(.sentences)
                .filledField(radius: 50)
        } else {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(appFont(15))
                .lineLimit(minLines...max(maxLines, minLines))
                .textInputAutocapitalization(.sentences)
                .filledField(radius: 16)
        }
    }
}

/// SDateBox — the YYYY / MM / DD boxes.
struct SDateBox: View {
    @Binding var value: String
    let placeholder: String
    let width: CGFloat
    let maxLength: Int

    var body: some View {
        TextField(placeholder, text: $value)
            .font(appFont(15, .bold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(width: width)
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .background(FieldFill)
            .rounded(8)
            .roundedBorder(value.isEmpty ? BorderGray : AppGreen, 1, radius: 8)
            .onChange(of: value) { _, newValue in
                let filtered = newValue.digitsOnly
                value = filtered.count > maxLength ? String(filtered.prefix(maxLength)) : filtered
            }
    }
}

/// STimeBox — the HH / MM boxes.
struct STimeBox: View {
    @Binding var value: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $value)
            .font(appFont(15, .bold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(width: 56)
            .padding(.vertical, 10)
            .background(FieldFill)
            .rounded(8)
            .roundedBorder(value.isEmpty ? BorderGray : AppGreen, 1, radius: 8)
            .onChange(of: value) { _, newValue in
                let filtered = newValue.digitsOnly
                value = filtered.count > 2 ? String(filtered.prefix(2)) : filtered
            }
    }
}

/// The "Date: YYYY-MM-DD" row shared by every task dialog.
struct DateRow: View {
    var label: String = "Date:"
    @Binding var year: String
    @Binding var month: String
    @Binding var day: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text(label).font(appFont(15, .bold))
            Spacer().frame(width: 8)
            SDateBox(value: $year, placeholder: "YYYY", width: 70, maxLength: 4)
            Text("-").font(appFont(15, .bold)).foregroundStyle(TextDark).padding(.horizontal, 3)
            SDateBox(value: $month, placeholder: "MM", width: 46, maxLength: 2)
            Text("-").font(appFont(15, .bold)).foregroundStyle(TextDark).padding(.horizontal, 3)
            SDateBox(value: $day, placeholder: "DD", width: 46, maxLength: 2)
            if let trailing { trailing }
        }
    }
}

/// The "Start: HH:MM" / "End: HH:MM" rows.
struct TimeRow: View {
    let label: String
    var labelWidth: CGFloat = 80
    @Binding var hour: String
    @Binding var minute: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(appFont(14, .bold))
                .frame(width: labelWidth, alignment: .leading)
            STimeBox(value: $hour, placeholder: "HH")
            Text(":").font(appFont(15, .bold)).foregroundStyle(TextDark).padding(.horizontal, 4)
            STimeBox(value: $minute, placeholder: "MM")
        }
    }
}

/// The pill-shaped dropdown used for Repeat / Assign to.
struct PillMenu<Item: Hashable, Label: View>: View {
    let items: [Item]
    let title: (Item) -> String
    let subtitle: ((Item) -> String?)?
    let noneLabel: String?
    let onSelect: (Item?) -> Void
    @ViewBuilder var label: Label

    init(items: [Item],
         title: @escaping (Item) -> String,
         subtitle: ((Item) -> String?)? = nil,
         noneLabel: String? = nil,
         onSelect: @escaping (Item?) -> Void,
         @ViewBuilder label: () -> Label) {
        self.items = items
        self.title = title
        self.subtitle = subtitle
        self.noneLabel = noneLabel
        self.onSelect = onSelect
        self.label = label()
    }

    var body: some View {
        Menu {
            if let noneLabel {
                Button(noneLabel) { onSelect(nil) }
            }
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    if let sub = subtitle?(item), sub.isNotBlank {
                        Text("\(title(item)) — \(sub)")
                    } else {
                        Text(title(item))
                    }
                }
            }
        } label: {
            label
        }
    }
}

/// The grey pill body a PillMenu shows for its current selection.
struct PillMenuLabel: View {
    let text: String
    var textColor: Color = TextGray

    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(appFont(14)).foregroundStyle(textColor)
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundStyle(TextGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(FieldFill)
        .rounded(50)
    }
}

struct ExpandableTaskSectionHeader: View {
    let title: String
    let expanded: Bool
    let onToggle: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(appFont(18, .bold))
                        .foregroundStyle(TextDark)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppGreen)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TextDark)
                    .frame(width: 34, height: 34)
                    .roundedBorder(Color(hex: 0xCCCCCC), 1, radius: 17)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

/// The white top bar with a back chevron and a centred title, repeated on most
/// of the settings/detail screens.
struct TopBar<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(appFont(18, .bold))
                .padding(.vertical, 16)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TextDark)
                        .padding(12)
                }
                .buttonStyle(.plain)
                Spacer()
                trailing
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
}

extension TopBar where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

/// Save (grey) + Cancel (pink) button pair used by every task dialog.
struct SaveCancelRow: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSave) {
                Text("Save")
                    .font(appFont(16, .semibold))
                    .foregroundStyle(Color(hex: 0x555555))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(SaveGray)
                    .rounded(50)
            }
            .buttonStyle(.plain)
            Button(action: onCancel) {
                Text("Cancel")
                    .font(appFont(16, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(CancelPink)
                    .rounded(50)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A full-width green primary button (login/signup/etc.).
struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(appFont(18, .semibold)).foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(enabled ? GreenButton : GreenButton.opacity(0.5))
            .rounded(50)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Error + retry block repeated on every list screen.
struct ErrorRetry: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message).font(appFont(14)).foregroundStyle(.red).multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("Retry")
                    .font(appFont(14, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppGreen)
                    .rounded(50)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
}

/// Small coloured dot used across the report screen.
struct Dot: View {
    let color: Color
    var size: CGFloat = 10
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}
