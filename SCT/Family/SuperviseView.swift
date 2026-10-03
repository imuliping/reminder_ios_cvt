//
//  SuperviseView.swift
//  Port of family/FamilySuperviseScreen.kt.
//

import SwiftUI

struct SuperviseView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = SuperviseViewModel()

    private var seniorName: String { TokenManager.getSeniorName() }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 0) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(TextDark)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(seniorName)'s Schedule")
                            .font(appFont(18, .bold)).foregroundStyle(TextDark)
                        Text("Senior").font(appFont(13)).foregroundStyle(TextGray)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            switch vm.tasksState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()

            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadTasks() }
                Spacer()

            case .success(let tasks):
                if tasks.isEmpty {
                    Spacer()
                    Text("No tasks for \(seniorName)").font(appFont(15)).foregroundStyle(TextGray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(tasks) { task in
                                SuperviseTaskRow(
                                    task: task,
                                    offer: vm.offersMap[task.taskId],
                                    isAssignedToMe: false,
                                    onComplete: { vm.completeTask(taskId: task.taskId) }
                                )
                            }
                            Spacer().frame(height: 16)
                            MessageEldaBar { onNavigate("family_aichat/family_supervise") }
                            Spacer().frame(height: 12)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable { vm.loadTasks() }
                }

            default:
                Spacer()
            }
        }
        .background(Color.white)
    }
}

// ── Task row ──────────────────────────────────────────────────────

struct SuperviseTaskRow: View {

    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onComplete: () -> Void

    @State private var checked: Bool?

    var body: some View {
        let iconStyle = getTaskIcon(task.displayName, task.description ?? "")
        let timeStr = formatTimeOnly(task.startDatetime ?? "")
        let isCompleted = ["completed", "done"].contains(task.status?.lowercased() ?? "")
            || ["completed", "done"].contains(task.taskStatusId?.lowercased() ?? "")
        let isOverdue = task.isOverdue
        let isChecked = checked ?? isCompleted

        VStack(alignment: .leading, spacing: 0) {
            if timeStr.isNotEmpty {
                Text(timeStr)
                    .font(appFont(15, .bold))
                    .foregroundStyle(TextDark)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: 0xDDDDDD))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: 0xEEEEEE))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: iconStyle.systemName)
                                    .font(.system(size: 19))
                                    .foregroundStyle(iconStyle.tint)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.displayName)
                                .font(appFont(15, .bold))
                                .foregroundStyle(isChecked ? TextGray : TextDark)
                            if let description = task.description, description.isNotBlank {
                                Text(description).font(appFont(13)).foregroundStyle(TextGray)
                            }
                            if let location = task.location, location.isNotBlank {
                                Text(location).font(appFont(12)).foregroundStyle(TextGray)
                            }
                            if let offer {
                                Spacer().frame(height: 4)
                                OfferStatusText(offer: offer, isAssignedToMe: isAssignedToMe)
                            }
                        }

                        Spacer()

                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppGreen)
                                .rounded(8)
                        } else if isOverdue {
                            OverdueBadge(onClick: onComplete)
                        } else {
                            Button {
                                checked = true
                                onComplete()
                            } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .frame(width: 34, height: 34)
                                    .roundedBorder(Color(hex: 0xAAAAAA), 2, radius: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(hex: 0xF5F5F5))
                .rounded(12)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
