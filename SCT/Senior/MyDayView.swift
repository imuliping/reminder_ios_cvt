//
//  MyDayView.swift
//  Port of senior/MyDayScreen.kt (screen, task row and quick-add dialog).
//

import SwiftUI

struct MyDayView: View {

    let onNavigate: (String) -> Void
    @StateObject private var vm = MyDayViewModel()

    @State private var showAddDialog = false
    @State private var editingTask: TaskItem?

    private var username: String { (TokenManager.getUsername() ?? "there").capitalizedFirst }
    private var myUserId: String? { TokenManager.getUserId() }
    private var tasks: [TaskItem] { vm.tasksState.data ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────
                HStack {
                    HStack(spacing: 10) {
                        Button { onNavigate("profile") } label: {
                            Circle()
                                .fill(Color(hex: 0xE0E0E0))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color(hex: 0x888888))
                                )
                        }
                        .buttonStyle(.plain)
                        HStack(spacing: 0) {
                            Text("Hi ").font(appFont(18)).foregroundStyle(TextDark)
                            Text(username).font(appFont(18, .bold)).foregroundStyle(TextDark)
                        }
                    }
                    Spacer()
                    Button { showAddDialog = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                            .foregroundStyle(TextDark)
                            .frame(width: 36, height: 36)
                            .roundedBorder(Color(hex: 0xCCCCCC), 1.5, radius: 18)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 18)

                content

                MessageEldaBar { onNavigate("aichat") }
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 20)
            .background(Color.white)

            BottomNavBar(current: "myday", onNavigate: onNavigate)
        }
        .sheet(isPresented: $showAddDialog) {
            MyDayTaskDialog(
                existingTask: nil,
                labels: vm.labels,
                priorityLevels: vm.priorityLevels,
                onDismiss: { showAddDialog = false },
                onSave: { title, desc, hour, minute, assignTo, repeatType, labelId, priorityId, weekdays in
                    vm.createQuickTask(title: title, description: desc, hour: hour,
                                       minute: minute, assignToUserId: assignTo,
                                       repeatTypeName: repeatType, labelId: labelId,
                                       priorityId: priorityId, selectedWeekdays: weekdays)
                    showAddDialog = false
                },
                onNavigate: onNavigate
            )
        }
        .sheet(item: $editingTask) { taskToEdit in
            MyDayEditSheet(
                task: taskToEdit,
                labels: vm.labels,
                priorityLevels: vm.priorityLevels,
                onDismiss: { editingTask = nil },
                onSave: { fullTask, title, desc, hour, minute, assignTo, repeatType, labelId, priorityId, weekdays in
                    vm.updateQuickTask(taskId: taskToEdit.taskId, title: title, description: desc,
                                       hour: hour, minute: minute, assignToUserId: assignTo,
                                       repeatTypeName: repeatType,
                                       originalDate: fullTask.startDatetime,
                                       labelId: labelId, priorityId: priorityId,
                                       selectedWeekdays: weekdays)
                    editingTask = nil
                },
                onNavigate: onNavigate
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = vm.tasksState.errorMessage {
            Spacer()
            ErrorRetry(message: message) { vm.loadTodayTasks() }
            Spacer()
        } else if tasks.isEmpty && !vm.tasksState.isLoading {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppGreen)
                Text("Nothing scheduled today!").font(appFont(16)).foregroundStyle(TextGray)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        let offer = vm.offersMap[task.taskId]
                        MyDayTaskRow(
                            task: task,
                            offer: offer,
                            isAssignedToMe: offer?.toUserId == myUserId,
                            onEdit: { editingTask = task },
                            onComplete: { vm.completeTask(taskId: task.taskId) },
                            onSkip: { vm.skipTask(taskId: task.taskId) },
                            onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                            onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                        )
                    }
                    Spacer().frame(height: 16)
                }
            }
            .refreshable { vm.loadTodayTasks() }
        }
    }
}

// ── Task Row ──────────────────────────────────────────────────────

struct MyDayTaskRow: View {

    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isAssignedToMe: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        let name = task.displayName
        let description = task.description?.nonBlank
        let timeStr = formatTimeOnly(task.startDatetime ?? "")
        let iconStyle = getTaskIcon(name, description ?? "")

        let statusLower = task.status?.lowercased()
        let statusIdLower = task.taskStatusId?.lowercased()
        let isCompleted = ["completed", "done"].contains(statusLower ?? "")
            || ["completed", "done"].contains(statusIdLower ?? "")
        let isSkipped = statusLower == "skipped"
        let isStarted = ["started", "in_progress"].contains(statusLower ?? "")
        let isOverdue = task.isOverdue

        let statusIndicator: StatusIndicator = {
            if isCompleted { return .completed }
            if isSkipped { return .skipped }
            if isStarted { return .started }
            if isOverdue { return .overdue }
            return .pending
        }()

        let offerStatus = offer?.status?.uppercased()
        let isPendingOffer = offerStatus == "PENDING"
        let isAcceptedOffer = offerStatus == "ACCEPTED"
        let isDeclinedOffer = offerStatus == "DECLINED"

        VStack(alignment: .leading, spacing: 0) {
            if timeStr.isNotEmpty {
                Text(timeStr)
                    .font(appFont(15, .bold))
                    .foregroundStyle(TextDark)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

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
                        Text(name)
                            .font(appFont(15, .bold))
                            .foregroundStyle(isSkipped ? TextGray : TextDark)
                        Text(task.statusText)
                            .font(appFont(12))
                            .foregroundStyle(isOverdue ? Color(hex: 0xC62828) : TextGray)
                        if (task.priorityLevel ?? 0) >= 4 {
                            Text("High priority")
                                .font(appFont(12, .bold))
                                .foregroundStyle(Color(hex: 0xC62828))
                        }
                        if let description {
                            Text(description)
                                .font(appFont(13))
                                .foregroundStyle(TextGray)
                                .lineSpacing(5)
                        }
                        if let location = task.location, location.isNotBlank {
                            Text(location).font(appFont(12)).foregroundStyle(TextGray)
                        }
                        if offer != nil {
                            let assignText: String = {
                                if isAssignedToMe && isPendingOffer  { return "Assigned to you — pending" }
                                if isAssignedToMe && isAcceptedOffer { return "Assigned to you — accepted" }
                                if isAssignedToMe && isDeclinedOffer { return "Assigned to you — declined" }
                                if isPendingOffer  { return "Assigned — pending response" }
                                if isAcceptedOffer { return "Assigned — accepted ✓" }
                                if isDeclinedOffer { return "Assigned — declined ✗" }
                                return "Assigned"
                            }()
                            let assignColor: Color = isAcceptedOffer ? AppGreen
                                : (isDeclinedOffer ? DangerRed : WarnAmber)
                            Text(assignText)
                                .font(appFont(12, .medium))
                                .foregroundStyle(assignColor)
                        }
                    }

                    Spacer()

                    // Status badge — tapping the pending/overdue box marks as complete
                    StatusBox(indicator: statusIndicator, onComplete: onComplete)
                }

                // Complete / Skip quick actions for active tasks
                if !isCompleted && !isSkipped {
                    HStack {
                        Spacer()
                        Button(action: onSkip) {
                            Text("Skip").font(appFont(13)).foregroundStyle(TextGray)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        Button(action: onComplete) {
                            Text("Done ✓").font(appFont(13, .semibold)).foregroundStyle(AppGreen)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                }

                if isAssignedToMe && isPendingOffer {
                    OfferActionRow(onAccept: onAccept, onDecline: onDecline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CardBg)
            .rounded(16)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Spacer().frame(height: 2)
        }
    }
}

// ── Quick add / edit dialog ───────────────────────────────────────

struct MyDayTaskDialog: View {

    var existingTask: TaskItem?
    let labels: [TaskLabel]
    let priorityLevels: [PriorityLevel]
    let onDismiss: () -> Void
    let onSave: (String, String, String, String, String?, String?, String, String, [String]?) -> Void
    var onNavigate: (String) -> Void = { _ in }

    @State private var title = ""
    @State private var description = ""
    @State private var remindHour = "09"
    @State private var remindMin = "00"
    @State private var errorMsg = ""
    @State private var selectedRepeat = "Never"
    @State private var selectedWeekdays: Set<String> = []
    @State private var selectedLabel: TaskLabel?
    @State private var selectedPriority: PriorityLevel?
    @State private var candidates: [TaskAssignmentCandidate] = []
    @State private var candidatesLoading = true
    @State private var selectedCandidate: TaskAssignmentCandidate?
    @State private var didInit = false

    private var repeatOptions: [String] {
        isEdit
            ? ["Keep current repeat", "Daily", "Weekly", "Monthly", "Yearly"]
            : ["Never", "Daily", "Weekly", "Monthly", "Yearly"]
    }

    private var isEdit: Bool { existingTask != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(isEdit ? "Edit Task" : "New Task")
                    .font(appFont(18, .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                if let existingTask {
                    TaskStatusControls(task: existingTask, onChanged: onDismiss)
                }

                Spacer().frame(height: 20)

                SDialogField(label: "Title", required: true) {
                    SRoundedField(text: $title)
                }

                Spacer().frame(height: 16)

                HStack(spacing: 0) {
                    Text("Label:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                    PillMenu(items: labels,
                             title: { $0.label },
                             subtitle: { _ in nil },
                             noneLabel: "Choose label",
                             onSelect: { selectedLabel = $0 }) {
                        PillMenuLabel(text: selectedLabel?.label ?? "Choose label")
                    }
                }

                Spacer().frame(height: 16)

                HStack(spacing: 0) {
                    Text("Priority:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                    PillMenu(items: priorityLevels,
                             title: { "Level \($0.priorityLevel)" },
                             subtitle: { $0.description },
                             noneLabel: "Choose priority",
                             onSelect: { selectedPriority = $0 }) {
                        PillMenuLabel(text: selectedPriority.map { "Level \($0.priorityLevel)" } ?? "Choose priority")
                    }
                }

                Spacer().frame(height: 16)

                SDialogField(label: "Description") {
                    SRoundedField(text: $description, singleLine: false, minLines: 4, maxLines: 6)
                }

                Spacer().frame(height: 16)

                HStack(spacing: 0) {
                    Text("Remind me at").font(appFont(15, .bold))
                    Text("*").font(appFont(15)).foregroundStyle(DangerRed)
                    Text(": ").font(appFont(15, .bold))
                    Spacer().frame(width: 8)
                    STimeBox(value: $remindHour, placeholder: "HH")
                    Text(" : ").font(appFont(16, .bold)).foregroundStyle(TextDark)
                    STimeBox(value: $remindMin, placeholder: "MM")
                }

                Spacer().frame(height: 16)

                HStack(spacing: 0) {
                    Text("Repeat:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                    Menu {
                        ForEach(repeatOptions, id: \.self) { option in
                            Button(option) { selectedRepeat = option }
                        }
                    } label: {
                        PillMenuLabel(text: selectedRepeat)
                    }
                }

                Spacer().frame(height: 16)

                if selectedRepeat == "Weekly" {
                    let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                    HStack(spacing: 6) {
                        ForEach(days, id: \.self) { day in
                            Button(day.prefix(1)) {
                                if selectedWeekdays.contains(day) {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(appFont(13, .semibold))
                            .foregroundStyle(selectedWeekdays.contains(day) ? .white : TextDark)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(selectedWeekdays.contains(day) ? AppGreen : Color(hex: 0xEEEEEE))
                            .clipShape(Circle())
                        }
                    }
                    Spacer().frame(height: 16)
                }

                HStack(spacing: 0) {
                    Text("Assign to:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                    if candidatesLoading {
                        ProgressView().tint(AppGreen).frame(width: 20, height: 20)
                    } else if candidates.isEmpty {
                        Text("No candidates available").font(appFont(13)).foregroundStyle(TextGray)
                    } else {
                        PillMenu(items: candidates,
                                 title: { $0.displayName ?? "Unknown" },
                                 subtitle: { $0.role?.capitalizedFirst },
                                 noneLabel: "No one",
                                 onSelect: { selectedCandidate = $0 }) {
                            PillMenuLabel(text: selectedCandidate?.displayName ?? "No one")
                        }
                    }
                }

                if errorMsg.isNotBlank {
                    Spacer().frame(height: 8)
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                }

                Spacer().frame(height: 24)

                SaveCancelRow(
                    onSave: {
                        if title.isBlank { errorMsg = "Title is required."; return }
                        guard let hour = Int(remindHour), (0...23).contains(hour),
                              let minute = Int(remindMin), (0...59).contains(minute) else {
                            errorMsg = "Enter a valid time (00–23 hours, 00–59 minutes)."
                            return
                        }
                        guard let labelId = selectedLabel?.labelId, !labelId.isBlank,
                              let priorityId = selectedPriority?.priorityLevelId else {
                            errorMsg = "Choose a label and priority."; return
                        }
                        if selectedRepeat == "Weekly" && selectedWeekdays.isEmpty {
                            errorMsg = "Choose at least one weekday."; return
                        }
                        let repeatType = ["Never", "Keep current repeat"].contains(selectedRepeat)
                            ? nil : selectedRepeat.lowercased()
                        onSave(title.trimmingCharacters(in: .whitespaces),
                               description.trimmingCharacters(in: .whitespaces),
                               remindHour.padStart(2, "0"),
                               remindMin.padStart(2, "0"),
                               selectedCandidate?.userId,
                               repeatType,
                               labelId,
                               priorityId,
                               selectedRepeat == "Weekly" ? Array(selectedWeekdays) : nil)
                    },
                    onCancel: onDismiss
                )

                Spacer().frame(height: 12)

                MessageEldaBar { onNavigate("aichat/myday") }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .task {
            guard !didInit else { return }
            didInit = true
            if let existingTask {
                selectedRepeat = "Keep current repeat"
                title = existingTask.displayName == "Untitled" ? "" : existingTask.displayName
                description = existingTask.description ?? ""
                if let raw = existingTask.startDatetime,
                   let instant = parseChatDate(raw) {
                    let hourFormatter = DateFormatter()
                    hourFormatter.locale = Locale(identifier: "en_US_POSIX")
                    hourFormatter.timeZone = userTimeZone()
                    hourFormatter.dateFormat = "HH"
                    let minuteFormatter = DateFormatter()
                    minuteFormatter.locale = Locale(identifier: "en_US_POSIX")
                    minuteFormatter.timeZone = userTimeZone()
                    minuteFormatter.dateFormat = "mm"
                    remindHour = hourFormatter.string(from: instant)
                    remindMin = minuteFormatter.string(from: instant)
                }
                selectedLabel = labels.first { $0.labelId == existingTask.labelId }
                selectedPriority = priorityLevels.first { $0.priorityLevelId == existingTask.priorityLevelId }
            }
            if selectedLabel == nil {
                selectedLabel = labels.first {
                    ["routine", "daily routine"].contains($0.label.lowercased())
                } ?? labels.first
            }
            if selectedPriority == nil {
                selectedPriority = priorityLevels.first { $0.priorityLevel == 2 } ?? priorityLevels.first
            }
            candidatesLoading = true
            await AppRepository.getAssignmentCandidates(taskId: existingTask?.taskId).onSuccess { list in
                let myId = TokenManager.getUserId()
                candidates = list.filter {
                    $0.userId != myId
                        && !($0.displayName.isNullOrBlank)
                        && $0.displayName?.lowercased() != "string"
                }
            }
            candidatesLoading = false
        }
    }
}

private struct MyDayEditSheet: View {
    let task: TaskItem
    let labels: [TaskLabel]
    let priorityLevels: [PriorityLevel]
    let onDismiss: () -> Void
    let onSave: (TaskItem, String, String, String, String, String?, String?, String, String, [String]?) -> Void
    let onNavigate: (String) -> Void

    @State private var fullTask: TaskItem?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let fullTask {
                MyDayTaskDialog(
                    existingTask: fullTask,
                    labels: labels,
                    priorityLevels: priorityLevels,
                    onDismiss: onDismiss,
                    onSave: { title, description, hour, minute, assignTo, repeatType, labelId, priorityId, weekdays in
                        onSave(fullTask, title, description, hour, minute, assignTo,
                               repeatType, labelId, priorityId, weekdays)
                    },
                    onNavigate: onNavigate)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Text("Open reminder").font(appFont(18, .bold))
                    Text(errorMessage).font(appFont(14)).foregroundStyle(DangerRed)
                    Button("Retry") { load() }
                    Button("Cancel", action: onDismiss)
                }
                .padding(24)
            } else {
                ProgressView("Opening reminder...")
                    .task { load() }
            }
        }
    }

    private func load() {
        errorMessage = nil
        Task {
            await AppRepository.getTask(taskId: task.taskId).fold(
                onSuccess: { fullTask = $0 },
                onFailure: { errorMessage = $0.message.isEmpty ? "Could not load reminder" : $0.message })
        }
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
