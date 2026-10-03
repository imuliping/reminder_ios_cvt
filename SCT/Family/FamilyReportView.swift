//
//  FamilyReportView.swift
//  Port of family/FamilyReportScreen.kt (screen, header, content and the shared
//  report sub-views that CaregiverReportView also uses).
//

import SwiftUI

struct FamilyReportView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = ReportViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ReportHeader(
                weekStart: vm.selectedWeekStart,
                onBack: onBack,
                onPrevWeek: { vm.selectPreviousWeek() },
                onNextWeek: { vm.selectNextWeek() }
            )

            switch vm.reportState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()
            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadReport() }
                Spacer()
            case .success(let data):
                ReportContent(data: data, seniorName: TokenManager.getSeniorName())
            default:
                Spacer()
            }

            FamilyBottomNavBar(current: "home", onNavigate: onNavigate)
        }
        .background(Color.white)
    }
}

// ─────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────

struct ReportHeader: View {

    let weekStart: String
    let onBack: () -> Void
    let onPrevWeek: () -> Void
    let onNextWeek: () -> Void

    /// "yyyy/MM/dd – yyyy/MM/dd" for the selected week.
    private var weekRangeLabel: String {
        let inFmt = DateFormatter()
        inFmt.locale = Locale.current
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.timeZone = userTimeZone()
        let displayFmt = DateFormatter()
        displayFmt.locale = Locale.current
        displayFmt.dateFormat = "yyyy/MM/dd"
        displayFmt.timeZone = userTimeZone()

        let start = inFmt.date(from: weekStart) ?? Date()
        var calendar = Calendar.current
        calendar.timeZone = userTimeZone()
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(displayFmt.string(from: start)) – \(displayFmt.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TextDark)
                        .padding(12)
                }
                .buttonStyle(.plain)
                Text("Weekly Report").font(appFont(18, .medium))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)

            HStack {
                Button(action: onPrevWeek) {
                    Text("<").font(appFont(16)).foregroundStyle(TextGray)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                Text(weekRangeLabel)
                    .font(appFont(14)).foregroundStyle(TextGray)
                Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(TextGray)
                Button(action: onNextWeek) {
                    Text(">").font(appFont(16)).foregroundStyle(TextGray)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer().frame(height: 12)
        }
    }
}

// ─────────────────────────────────────────────────────────────────
//  REPORT CONTENT
// ─────────────────────────────────────────────────────────────────

struct ReportContent: View {

    let data: WeeklySummaryData
    let seniorName: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Weekly Summary ────────────────────────────────
                let ws = data.weeklySummary
                ReportCard(title: "Weekly Summary") {
                    ReportRow(label: "Medication Adherence",
                              value: "\(ws?.medicationAdherencePct.map(String.init) ?? "--")% This Week",
                              indicator: (ws?.medicationAdherencePct ?? 0) >= 80 ? .greenCheck : .yellowDot)
                    ReportRow(label: "Critical Missed Tasks",
                              value: "\(ws?.criticalMissedTasksCount ?? 0) Alert",
                              indicator: (ws?.criticalMissedTasksCount ?? 0) > 0 ? .redDot : .greenDot)
                    ReportRow(label: "Appointments Kept",
                              value: "\(ws?.appointmentsKept.map(String.init) ?? "--") / \(ws?.appointmentsTotal.map(String.init) ?? "--")",
                              indicator: .greenDot)
                    ReportRow(label: "Caregiver Visits",
                              value: "\(ws?.caregiverVisitsCompleted.map(String.init) ?? "--") Completed",
                              indicator: .greenCheck)
                    Spacer().frame(height: 12)
                    // Elda summary — data-driven based on actual results
                    EldaBubble(text: {
                        let hasMissed = (ws?.criticalMissedTasksCount ?? 0) > 0
                        let adherence = ws?.medicationAdherencePct ?? 100
                        if hasMissed && adherence < 80 {
                            return "\(seniorName) missed some critical tasks and medication adherence needs attention this week."
                        }
                        if hasMissed {
                            return "Overall, \(seniorName) stayed on track this week. One or more tasks required follow-up."
                        }
                        if adherence < 80 {
                            return "\(seniorName) completed tasks on time but medication adherence could be improved."
                        }
                        return "Great week! \(seniorName) completed all scheduled tasks on time."
                    }())
                }

                // ── Medication Adherence ──────────────────────────
                let ma = data.medicationAdherence
                ReportCard(title: "Medication Adherence") {
                    LabelValueRow(label: "Prescribed Medications",
                                  value: ma?.prescribedMedications?.joined(separator: ", ").nonBlank ?? "None listed",
                                  bold: true)
                    Divider().padding(.vertical, 8).background(Color(hex: 0xEEEEEE))
                    LabelValueRow(label: "Taken On Time", value: "\(ma?.takenOnTimePct.map(String.init) ?? "--")%")
                    LabelValueRow(label: "Taken Late", value: "\(ma?.takenLatePct.map(String.init) ?? "--")%")
                    LabelValueRow(label: "Missed", value: "\(ma?.missedPct.map(String.init) ?? "--")%")
                    LabelValueRow(label: "Escalations Triggered", value: "\(ma?.escalationsTriggered ?? 0)")
                    Divider().padding(.vertical, 8).background(Color(hex: 0xEEEEEE))
                    HStack {
                        Spacer()
                        Text("Insight Badge: ").font(appFont(14, .medium))
                        let badge = ma?.insightBadge?.lowercased() ?? "stable"
                        let badgeColor: Color = {
                            if badge.contains("stable") || badge.contains("good") { return AppGreen }
                            if badge.contains("warning") || badge.contains("moderate") { return WarnAmber }
                            if badge.contains("critical") || badge.contains("poor") { return DangerRed }
                            return AppGreen
                        }()
                        Dot(color: badgeColor)
                        Spacer().frame(width: 6)
                        Text(ma?.insightBadge?.capitalizedFirst ?? "Stable").font(appFont(14, .medium))
                        Spacer()
                    }
                }

                // ── Daily Routine & Stability ─────────────────────
                let dr = data.dailyRoutineStability
                ReportCard(title: "Daily Routine & Stability") {
                    HStack {
                        Text("Indicator").font(appFont(13, .bold)).foregroundStyle(TextDark)
                        Spacer()
                        Text("Status").font(appFont(13, .bold)).foregroundStyle(TextDark)
                    }
                    Divider().padding(.vertical, 6).background(Color(hex: 0xEEEEEE))

                    if let indicators = dr?.indicators, !indicators.isEmpty {
                        ForEach(indicators) { indicator in
                            let statusLower = indicator.status?.lowercased() ?? ""
                            // Handles all backend status values including "Needs Attention"
                            let dotColor: Color = {
                                if statusLower.contains("stable") || statusLower.contains("consistent")
                                    || statusLower.contains("good") { return AppGreen }
                                if statusLower.contains("needs") || statusLower.contains("attention")
                                    || statusLower.contains("slight") || statusLower.contains("moderate")
                                    || statusLower.contains("improving") { return WarnAmber }
                                if statusLower.contains("poor") || statusLower.contains("declining")
                                    || statusLower.contains("critical") { return DangerRed }
                                return WarnAmber   // unknown = yellow (caution)
                            }()
                            RoutineRow(indicator: indicator.name ?? "",
                                       status: indicator.status ?? "",
                                       dotColor: dotColor)
                            Spacer().frame(height: 6)
                        }
                    } else {
                        Text("No routine data available").font(appFont(13)).foregroundStyle(TextGray)
                    }

                    // Data-driven Elda note
                    let needsAttention = dr?.indicators?.contains { indicator in
                        let s = indicator.status?.lowercased() ?? ""
                        return s.contains("needs") || s.contains("attention")
                            || s.contains("poor") || s.contains("declining")
                    } ?? false
                    Spacer().frame(height: 8)
                    EldaBubble(text: needsAttention
                        ? "Some routine indicators need attention. Consider checking in with the senior about their daily habits."
                        : "Daily routine looks consistent this week. Keep up the great work!")
                }

                // ── Appointment & Schedule Reliability ────────────
                let ar = data.appointmentReliability
                ReportCard(title: "Appointment & Schedule Reliability") {
                    HStack {
                        ForEach([("Scheduled", ar?.scheduled ?? 0),
                                 ("Attended", ar?.attended ?? 0),
                                 ("Late", ar?.late ?? 0),
                                 ("Missed", ar?.missed ?? 0)], id: \.0) { label, value in
                            VStack(spacing: 4) {
                                Text(label)
                                    .font(appFont(12))
                                    .foregroundStyle(TextGray)
                                    .multilineTextAlignment(.center)
                                Text("\(value)").font(appFont(18, .bold)).foregroundStyle(TextDark)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Spacer().frame(height: 8)
                    let total = max(ar?.scheduled ?? 0, 1)
                    let attended = ar?.attended ?? 0
                    ProgressView(value: Double(attended), total: Double(total))
                        .progressViewStyle(.linear)
                        .tint(AppGreen)
                        .frame(height: 6)
                }

                // ── Alerts & Escalation History ───────────────────
                ReportCard(title: "Alerts & Escalation History") {
                    HStack {
                        ForEach(["Date", "Task", "Level", "Action"], id: \.self) { header in
                            Text(header)
                                .font(appFont(12, .bold))
                                .foregroundStyle(TextDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Divider().padding(.vertical, 6).background(Color(hex: 0xEEEEEE))

                    if let escalations = data.escalations, !escalations.isEmpty {
                        ForEach(escalations) { esc in
                            let levelColor: Color = {
                                if (esc.level ?? 0) >= 5 { return DangerRed }
                                if (esc.level ?? 0) >= 3 { return Color(hex: 0xFF9800) }
                                return WarnAmber
                            }()
                            AlertRow(date: esc.date ?? "--",
                                     task: esc.task ?? "--",
                                     level: esc.level.map(String.init) ?? "--",
                                     levelColor: levelColor,
                                     action: esc.action ?? "--")
                            Spacer().frame(height: 6)
                        }
                    } else {
                        Text("No escalations this week").font(appFont(13)).foregroundStyle(TextGray)
                    }
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 16)
        }
    }
}

// ─────────────────────────────────────────────────────────────────
//  SHARED SUB-VIEWS
// ─────────────────────────────────────────────────────────────────

struct ReportCard<Content: View>: View {
    let title: String
    var titleExtra: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(appFont(16, .bold)).foregroundStyle(TextDark)
                Spacer()
                if let titleExtra {
                    Text(titleExtra).font(appFont(14)).foregroundStyle(TextGray)
                }
            }
            Spacer().frame(height: 12)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .rounded(12)
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }
}

enum ReportIndicator { case greenCheck, greenDot, redDot, yellowDot }

struct ReportRow: View {
    let label: String
    let value: String
    let indicator: ReportIndicator

    var body: some View {
        HStack {
            Text(label).font(appFont(13)).foregroundStyle(TextDark)
            Spacer()
            HStack(spacing: 6) {
                switch indicator {
                case .greenCheck: Text("✅").font(appFont(14))
                case .greenDot:   Dot(color: AppGreen)
                case .redDot:     Dot(color: DangerRed)
                case .yellowDot:  Dot(color: WarnAmber)
                }
                Text(value).font(appFont(13, .medium)).foregroundStyle(TextDark)
            }
        }
        .padding(.vertical, 5)
    }
}

struct LabelValueRow: View {
    let label: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label).font(appFont(13, bold ? .bold : .regular)).foregroundStyle(TextDark)
            Spacer()
            Text(value).font(appFont(13, bold ? .bold : .regular)).foregroundStyle(TextDark)
        }
        .padding(.vertical, 4)
    }
}

struct RoutineRow: View {
    let indicator: String
    let status: String
    let dotColor: Color

    var body: some View {
        HStack {
            Text(indicator).font(appFont(13)).foregroundStyle(TextDark)
            Spacer()
            Dot(color: dotColor)
            Spacer().frame(width: 6)
            Text(status).font(appFont(13)).foregroundStyle(TextDark)
        }
    }
}

struct AlertRow: View {
    let date: String
    let task: String
    let level: String
    let levelColor: Color
    let action: String

    var body: some View {
        HStack {
            Text(date).font(appFont(13)).foregroundStyle(TextDark)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(task).font(appFont(13)).foregroundStyle(TextDark)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Dot(color: levelColor)
                Text(level).font(appFont(13)).foregroundStyle(TextDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(action).font(appFont(13)).foregroundStyle(TextDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EldaBubble: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            EldaAvatar(size: 44)
            Text(text).font(appFont(13)).foregroundStyle(TextGray)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF5F5F5))
        .rounded(12)
    }
}
