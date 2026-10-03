//
//  CaregiverAvailableTimeView.swift
//  Port of caregiver/CaregiverAvaliableTimeScreen.kt.
//

import SwiftUI

struct CaregiverAvailableTimeView: View {

    let onBack: () -> Void
    let onAddTask: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = CaregiverAvailableTimeViewModel()

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TextDark)
                        .padding(12)
                }
                .buttonStyle(.plain)
                Text("Senior's Availability").font(appFont(18, .medium))
                Spacer()
                Button(action: onAddTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundStyle(TextDark)
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)

            // ── Day picker ────────────────────────────────────────
            HStack {
                Menu {
                    ForEach(vm.availableDays) { day in
                        Button(day.display) { vm.selectDay(day) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.selectedDay?.display ?? "")
                            .font(appFont(16, .medium))
                            .foregroundStyle(TextGray)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(TextGray)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)

            // ── Time slots ────────────────────────────────────────
            switch vm.slotsState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()

            case .success(let slots):
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(slots) { slot in
                            TimeSlotRow(slot: slot) {
                                if !slot.isLocked { onAddTask() }
                            }
                        }
                        Spacer().frame(height: 16)
                        MessageEldaBar { onNavigate("caregiver_aichat/caregiver_home") }
                        Spacer().frame(height: 12)
                    }
                    .padding(.horizontal, 20)
                }

            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadSlots() }
                Spacer()

            default:
                Spacer()
            }

            CaregiverBottomNavBar(current: "home", onNavigate: onNavigate)
        }
        .background(Color.white)
    }
}

struct TimeSlotRow: View {

    let slot: TimeSlot
    let onClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slot.time)
                .font(appFont(15, .medium))
                .foregroundStyle(TextDark)
                .padding(.top, 12)
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(hex: 0xDDDDDD))
                    .frame(width: 3, height: slot.isLocked ? 64 : 44)

                if slot.isLocked {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Text("locked").font(appFont(16, .medium)).foregroundStyle(TextDark)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(TextDark)
                        }
                        if let taskTitle = slot.taskTitle, taskTitle.isNotBlank {
                            Text(taskTitle).font(appFont(12)).foregroundStyle(TextGray)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Color(hex: 0xDDDDDD))
                    .rounded(12)
                } else {
                    Button(action: onClick) {
                        Rectangle()
                            .fill(Color(hex: 0xF0F0F0))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .rounded(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
