//
//  TaskCards.swift
//  Ports of ScheduleTaskCard / TodoTaskCard (senior/ScheduleScreen.kt) and
//  FamilyScheduleTaskCard / FamilyTodoTaskCard (family/FamilyScheduleScreen.kt),
//  the latter two being reused by the caregiver schedule screen.
//

import SwiftUI

/// Shared body: date box, title block, edit pencil, status box, offer actions.
private struct BaseTaskCard: View {

    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    /// Schedule cards show the time line; to-do cards fall back to location.
    let showTimeLine: Bool
    let titleWeight: Font.Weight
    /// Android's senior cards call onComplete when the empty box is tapped;
    /// the family cards only flip the local checkbox.
    let completeOnCheck: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var checked = false

    var body: some View {
        let isCompleted = ["completed", "done"].contains(task.status?.lowercased() ?? "")
        let isOverdue = task.isOverdue
        let isPending = offer?.status?.uppercased() == "PENDING"
        let dateText = formatDateBox(task.startDatetime ?? "")

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Date box
                VStack(spacing: 0) {
                    Text(dateText.0).font(appFont(22, .bold))
                    Text(dateText.1).font(appFont(13, .bold)).foregroundStyle(TextDark)
                }
                .frame(width: 64, height: 64)
                .background(Color.white)
                .rounded(10)

                Spacer().frame(width: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.displayName)
                        .font(appFont(15, titleWeight))
                        .foregroundStyle(TextDark)
                    if showTimeLine {
                        if let start = task.startDatetime, !start.isEmpty {
                            Text(formatTimeOnly(start)).font(appFont(13)).foregroundStyle(TextGray)
                        }
                        if let description = task.description, !description.isEmpty {
                            Text(description).font(appFont(13)).foregroundStyle(TextGray)
                        }
                        if let location = task.location, !location.isEmpty {
                            Text(location).font(appFont(13)).foregroundStyle(TextGray)
                        }
                    } else {
                        if let description = task.description, !description.isEmpty {
                            Text(description).font(appFont(13)).foregroundStyle(TextGray)
                        } else if let location = task.location, !location.isEmpty {
                            Text(location).font(appFont(13)).foregroundStyle(TextGray)
                        }
                    }
                    if let offer {
                        Spacer().frame(height: 4)
                        OfferStatusText(offer: offer, isAssignedToMe: isAssignedToMe)
                    }
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15))
                        .foregroundStyle(TextGray)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                if isCompleted || checked {
                    Button(action: onComplete) {
                        Text("✓")
                            .font(appFont(14, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(AppGreen)
                            .rounded(6)
                    }
                    .buttonStyle(.plain)
                } else if isOverdue {
                    OverdueBadge(onClick: onComplete)
                } else {
                    Button {
                        checked = true
                        if completeOnCheck { onComplete() }
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)
                            .roundedBorder(Color(hex: 0x999999), 2, radius: 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isAssignedToMe && isPending {
                OfferActionRow(onAccept: onAccept, onDecline: onDecline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBg)
        .rounded(12)
        .padding(.vertical, 2)
    }
}

// ── Senior cards ──────────────────────────────────────────────────

struct ScheduleTaskCard: View {
    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        BaseTaskCard(task: task, offer: offer, isAssignedToMe: isAssignedToMe,
                     showTimeLine: true, titleWeight: .bold, completeOnCheck: true,
                     onEdit: onEdit, onComplete: onComplete,
                     onAccept: onAccept, onDecline: onDecline)
    }
}

struct TodoTaskCard: View {
    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        BaseTaskCard(task: task, offer: offer, isAssignedToMe: isAssignedToMe,
                     showTimeLine: false, titleWeight: .medium, completeOnCheck: true,
                     onEdit: onEdit, onComplete: onComplete,
                     onAccept: onAccept, onDecline: onDecline)
    }
}

// ── Family / caregiver cards ──────────────────────────────────────

struct FamilyScheduleTaskCard: View {
    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        BaseTaskCard(task: task, offer: offer, isAssignedToMe: isAssignedToMe,
                     showTimeLine: true, titleWeight: .bold, completeOnCheck: false,
                     onEdit: onEdit, onComplete: onComplete,
                     onAccept: onAccept, onDecline: onDecline)
    }
}

struct FamilyTodoTaskCard: View {
    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        BaseTaskCard(task: task, offer: offer, isAssignedToMe: isAssignedToMe,
                     showTimeLine: false, titleWeight: .medium, completeOnCheck: false,
                     onEdit: onEdit, onComplete: onComplete,
                     onAccept: onAccept, onDecline: onDecline)
    }
}

/// Port of the "edit recurring task" scope picker shown before the task dialog.
/// `scopes` lets the family screen omit the "forward" option, as on Android.
struct RecurringEditScopeDialog: View {
    var includeForward: Bool = true
    let onPick: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Edit recurring task").font(appFont(18, .bold))
            Text("What would you like to edit?")
                .font(appFont(14)).foregroundStyle(TextGray)
            Spacer().frame(height: 8)

            Button { onPick("single") } label: {
                Text("This task only")
                    .font(appFont(15, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppGreen).rounded(10)
            }
            .buttonStyle(.plain)

            if includeForward {
                Button { onPick("forward") } label: {
                    Text("This and all future tasks")
                        .font(appFont(15)).foregroundStyle(TextDark)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .roundedBorder(BorderGray, 1, radius: 10)
                }
                .buttonStyle(.plain)
            }

            Button { onPick("all") } label: {
                Text("All tasks in the series")
                    .font(appFont(15)).foregroundStyle(TextDark)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .roundedBorder(BorderGray, 1, radius: 10)
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(appFont(15)).foregroundStyle(TextGray)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .presentationDetents([.height(includeForward ? 340 : 290)])
    }
}
