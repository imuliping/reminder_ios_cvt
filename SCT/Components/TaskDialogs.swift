//
//  TaskDialogs.swift
//  Ports of the four task dialogs:
//    • SeniorNewTaskDialog  — senior/ScheduleScreen.kt
//    • TodoTaskDialog       — senior/ToDoTaskDialogue.kt
//    • UnifiedTaskDialog    — family/FamilyScheduleScreen.kt
//    • CaregiverTaskDialog  — caregiver/CaregiverScheduleScreen.kt
//

import SwiftUI

/// (title, description, labelId, priorityId, startDt, endDt, location, assignTo, repeatTypeName)
typealias TaskDialogSave = (String, String, String, String, String, String, String?, String?, String?) -> Void

/// Caregivers cannot assign, so their dialog drops the assignTo parameter.
typealias CaregiverTaskDialogSave = (String, String, String, String, String, String, String?, String?) -> Void

/// Shared "Repeat:" option list loader. Returns (label, repeatTypeId?) pairs.
@MainActor
private func loadRepeatOptions(includeNeverFirst: Bool, ordered: Bool) async -> [(String, String?)] {
    var options: [(String, String?)] = includeNeverFirst ? [("Never", nil)] : []
    await AppRepository.getRecurrenceTypes().fold(
        onSuccess: { types in
            if ordered {
                // family/caregiver dialogs sort the known names first, then the rest
                let orderedNames = ["none", "hourly", "daily", "weekly", "monthly", "yearly"]
                var byName: [String: RecurrenceType] = [:]
                for t in types { byName[t.recurrenceType.lowercased()] = t }
                let head = orderedNames.compactMap { name -> (String, String?)? in
                    guard let t = byName[name] else { return nil }
                    return (t.recurrenceType.capitalizedFirst, t.repeatTypeId)
                }
                let leftover = types
                    .filter { !orderedNames.contains($0.recurrenceType.lowercased()) }
                    .map { ($0.recurrenceType.capitalizedFirst, Optional($0.repeatTypeId)) }
                options += head + leftover
            } else {
                options += types.map { ($0.recurrenceType.capitalizedFirst, Optional($0.repeatTypeId)) }
            }
        },
        onFailure: { LogManager.logError("getRecurrenceTypes failed: \($0.message)") }
    )
    return options
}

/// Splits "yyyy-MM-ddTHH:mm:ss" into its parts for dialog prefill.
private func splitDatetime(_ dt: String?) -> (y: String, m: String, d: String, hh: String, mm: String) {
    guard let dt else { return ("", "", "", "", "") }
    let parts = dt.split(separator: "T").map(String.init)
    guard parts.count == 2 else { return ("", "", "", "", "") }
    let dateComps = parts[0].split(separator: "-").map(String.init)
    let timeComps = parts[1].split(separator: ":").map(String.init)
    return (
        dateComps.count == 3 ? dateComps[0] : "",
        dateComps.count == 3 ? dateComps[1] : "",
        dateComps.count == 3 ? dateComps[2] : "",
        timeComps.count >= 2 ? timeComps[0] : "",
        timeComps.count >= 2 ? timeComps[1] : ""
    )
}

/// Builds the start/end datetime strings the way every dialog's Save button does.
private func buildDatetimes(year: String, month: String, day: String,
                            startHour: String, startMin: String,
                            endHour: String, endMin: String) -> (String, String) {
    let dateStr = (year.isNotBlank && month.isNotBlank && day.isNotBlank)
        ? "\(year.padStart(4, "0"))-\(month.padStart(2, "0"))-\(day.padStart(2, "0"))"
        : todayString()
    let startH = Int(startHour) ?? 0
    let startM = Int(startMin) ?? 0
    let startDt = "\(dateStr)T\(String(startH).padStart(2, "0")):\(String(startM).padStart(2, "0")):00"
    let endDt: String
    if endHour.isNotBlank {
        let endH = Int(endHour) ?? 0
        let endM = Int(endMin) ?? 0
        endDt = "\(dateStr)T\(String(endH).padStart(2, "0")):\(String(endM).padStart(2, "0")):00"
    } else {
        let endH = min(startH + 1, 23)
        endDt = "\(dateStr)T\(String(endH).padStart(2, "0")):\(String(startM).padStart(2, "0")):00"
    }
    return (startDt, endDt)
}

struct TaskStatusControls: View {
    let task: TaskItem
    let onChanged: () -> Void

    @State private var status: String?
    @State private var hiddenFromFamily: Bool
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var showSkipConfirm = false

    init(task: TaskItem, onChanged: @escaping () -> Void) {
        self.task = task
        self.onChanged = onChanged
        _status = State(initialValue: task.status ?? task.taskStatusId)
        _hiddenFromFamily = State(initialValue: task.hiddenFromFamily == true)
    }

    private var statusText: String {
        switch status?.lowercased() {
        case "completed", "done": return "Completed"
        case "skipped": return "Skipped"
        case "missed": return "Missed"
        case "canceled", "cancelled": return "Canceled"
        case "started", "in_progress": return "In progress"
        default: return task.isOverdue ? "Overdue" : "Scheduled"
        }
    }

    private var canChangeStatus: Bool {
        task.canComplete == true
            && !["done", "completed", "skipped", "cancelled", "canceled"]
                .contains(status?.lowercased() ?? "")
    }

    private var canHideFromFamily: Bool {
        TokenManager.isSenior()
            && (task.subjectUserId == nil || task.subjectUserId == TokenManager.getUserId())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status: \(statusText)")
                .font(appFont(15, .semibold))
                .foregroundStyle(TextDark)

            if let errorMessage {
                Text(errorMessage)
                    .font(appFont(13))
                    .foregroundStyle(DangerRed)
            }

            if canHideFromFamily {
                Toggle("Hide from family", isOn: Binding(
                    get: { hiddenFromFamily },
                    set: updateVisibility
                ))
                .font(appFont(14))
                .tint(AppGreen)
                .disabled(busy)
            }

            if canChangeStatus {
                Button {
                    changeStatus(skip: false)
                } label: {
                    Text("Mark completed")
                        .font(appFont(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppGreen)
                        .rounded(50)
                }
                .buttonStyle(.plain)
                .disabled(busy)

                Button {
                    showSkipConfirm = true
                } label: {
                    Text("Skip this task")
                        .font(appFont(15, .semibold))
                        .foregroundStyle(TextDark)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .roundedBorder(BorderGray, 1, radius: 50)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }

            if busy {
                ProgressView().tint(AppGreen).frame(maxWidth: .infinity)
            }
        }
        .alert("Skip this task?", isPresented: $showSkipConfirm) {
            Button("Skip task", role: .destructive) { changeStatus(skip: true) }
            Button("Keep task", role: .cancel) {}
        } message: {
            Text("This stops reminders for this task occurrence. Future repeating tasks stay scheduled.")
        }
    }

    private func changeStatus(skip: Bool) {
        busy = true
        errorMessage = nil
        Task {
            let result = skip
                ? await AppRepository.skipTask(taskId: task.taskId)
                : await AppRepository.completeTask(taskId: task.taskId)
            await result.fold(
                onSuccess: { _ in
                    status = skip ? "skipped" : "done"
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    NotificationEventBus.shared.triggerNotificationRefresh()
                    busy = false
                    onChanged()
                },
                onFailure: { error in
                    errorMessage = error.message.isEmpty
                        ? "Unable to change task status. Please try again."
                        : error.message
                    busy = false
                }
            )
        }
    }

    private func updateVisibility(_ hidden: Bool) {
        busy = true
        errorMessage = nil
        Task {
            await AppRepository.setTaskFamilyVisibility(taskId: task.taskId, hidden: hidden).fold(
                onSuccess: { _ in
                    hiddenFromFamily = hidden
                    NotificationEventBus.shared.triggerScheduleRefresh()
                    busy = false
                },
                onFailure: { error in
                    errorMessage = error.message.isEmpty
                        ? "Could not update task visibility."
                        : error.message
                    busy = false
                }
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────
//  SENIOR NEW/EDIT TASK DIALOG
// ─────────────────────────────────────────────────────────────────

struct SeniorNewTaskDialog: View {

    var existingTask: TaskItem?
    let labels: [TaskLabel]
    let priorityLevels: [PriorityLevel]
    var showAssignTo: Bool = true
    var isTodo: Bool = false
    var hasRecurrence: Bool = false
    var currentRepeatTypeId: String?
    var onStopRepeating: (() -> Void)?
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void
    let onSave: TaskDialogSave

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var errorMsg = ""
    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var startHour = ""
    @State private var startMin = ""
    @State private var endHour = ""
    @State private var endMin = ""
    @State private var selectedLabel: TaskLabel?
    @State private var selectedPriority: PriorityLevel?
    @State private var selectedRepeatLabel = "Never"
    @State private var selectedRepeatTypeId: String?
    @State private var repeatOptions: [(String, String?)] = [("Never", nil)]
    @State private var repeatPreselected = false
    @State private var candidates: [TaskAssignmentCandidate] = []
    @State private var candidatesLoading = false
    @State private var selectedCandidate: TaskAssignmentCandidate?
    @State private var showDeleteConfirm = false
    @State private var didInit = false

    private var isEdit: Bool { existingTask != nil }
    private var relevantLabels: [TaskLabel] { isTodo ? [] : labels }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ZStack {
                    Text(isEdit ? "Edit Task" : "New Task")
                        .font(appFont(18, .bold))
                        .frame(maxWidth: .infinity)
                    if isEdit, onDelete != nil {
                        HStack {
                            Spacer()
                            Button { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(DangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 16)

                if let existingTask {
                    TaskStatusControls(task: existingTask, onChanged: onDismiss)
                    Spacer().frame(height: 12)
                }

                SDialogField(label: "Title", required: true) { SRoundedField(text: $title) }
                Spacer().frame(height: 12)
                SDialogField(label: "Description") {
                    SRoundedField(text: $description, singleLine: false, minLines: 3, maxLines: 5)
                }
                Spacer().frame(height: 12)

                DateRow(year: $dateYear, month: $dateMonth, day: $dateDay)
                Spacer().frame(height: 12)
                TimeRow(label: "Start:", hour: $startHour, minute: $startMin)
                Spacer().frame(height: 8)
                TimeRow(label: "End:", hour: $endHour, minute: $endMin)
                Spacer().frame(height: 12)

                SDialogField(label: "Location") { SRoundedField(text: $location) }
                Spacer().frame(height: 12)

                if !relevantLabels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category (optional)").font(appFont(12)).foregroundStyle(TextGray)
                        PillMenu(items: relevantLabels,
                                 title: { $0.label },
                                 noneLabel: "None (auto-detect)",
                                 onSelect: { selectedLabel = $0 }) {
                            HStack {
                                Text(selectedLabel?.label ?? "None (auto-detect)")
                                    .font(appFont(15)).foregroundStyle(TextDark)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundStyle(TextGray)
                            }
                            .padding(12)
                            .roundedBorder(BorderGray, 1, radius: 12)
                        }
                    }
                    Spacer().frame(height: 12)
                }

                // Repeat — shown for both create and edit
                HStack(spacing: 0) {
                    Text("Repeat:").font(appFont(15, .bold)).frame(width: 80, alignment: .leading)
                    Menu {
                        ForEach(repeatOptions.indices, id: \.self) { index in
                            let option = repeatOptions[index]
                            Button(option.0) {
                                selectedRepeatLabel = option.0
                                selectedRepeatTypeId = option.1
                            }
                        }
                    } label: {
                        PillMenuLabel(text: selectedRepeatLabel, textColor: TextDark)
                    }
                }
                if selectedRepeatTypeId != nil {
                    Spacer().frame(height: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "repeat").font(.system(size: 12)).foregroundStyle(AppGreen)
                        Text("Repeats \(selectedRepeatLabel)").font(appFont(12)).foregroundStyle(AppGreen)
                    }
                }

                Spacer().frame(height: 24)

                if showAssignTo {
                    HStack(spacing: 0) {
                        Text("Assign to:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                        if candidatesLoading {
                            ProgressView().tint(AppGreen).frame(width: 20, height: 20)
                        } else if candidates.isEmpty {
                            Text("No candidates").font(appFont(13)).foregroundStyle(TextGray)
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
                    Spacer().frame(height: 12)
                }

                if errorMsg.isNotBlank {
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                    Spacer().frame(height: 8)
                }

                SaveCancelRow(onSave: save, onCancel: onDismiss)
                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            if hasRecurrence, let onStopRepeating {
                Button("Stop repeating series", role: .destructive) { onStopRepeating() }
            }
            Button(hasRecurrence ? "Delete this task only" : "Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hasRecurrence
                 ? "This is a recurring task. What would you like to do?"
                 : "This task will be permanently deleted.")
        }
        .task {
            guard !didInit else { return }
            didInit = true

            if let existingTask {
                title = existingTask.displayName == "Untitled" ? "" : existingTask.displayName
                description = existingTask.description ?? ""
                location = existingTask.location ?? ""
                let start = splitDatetime(existingTask.startDatetime)
                dateYear = start.y; dateMonth = start.m; dateDay = start.d
                startHour = start.hh; startMin = start.mm
                let end = splitDatetime(existingTask.endDatetime)
                endHour = end.hh; endMin = end.mm
                selectedLabel = labels.first { $0.labelId == existingTask.labelId }
                selectedPriority = priorityLevels.first { $0.priorityLevelId == existingTask.priorityLevelId }
            }
            if isTodo { selectedLabel = labels.first { $0.labelId == todoLabelId } }
            if selectedPriority == nil {
                selectedPriority = priorityLevels.first { $0.priorityLevel == 2 } ?? priorityLevels.first
            }

            repeatOptions = await loadRepeatOptions(includeNeverFirst: true, ordered: false)
            if !repeatPreselected, repeatOptions.count > 1, let currentRepeatTypeId,
               let match = repeatOptions.first(where: { $0.1 == currentRepeatTypeId }) {
                selectedRepeatLabel = match.0
                selectedRepeatTypeId = match.1
                repeatPreselected = true
            }

            if showAssignTo {
                candidatesLoading = true
                await AppRepository.getAssignmentCandidates(taskId: existingTask?.taskId).onSuccess { list in
                    let myId = TokenManager.getUserId()
                    candidates = list.filter {
                        $0.userId != myId && !($0.displayName.isNullOrBlank)
                            && $0.displayName?.lowercased() != "string"
                    }
                    if selectedCandidate == nil {
                        selectedCandidate = existingTask?.assignedToUserId
                            .flatMap { id in candidates.first { $0.userId == id } }
                            ?? candidates.first { $0.offerStatus?.lowercased() == "accepted" }
                    }
                }
                candidatesLoading = false
            }
        }
    }

    private func save() {
        if title.isBlank { errorMsg = "Title is required."; return }
        let labelId = isTodo ? todoLabelId : (selectedLabel?.labelId ?? "")
        let priorityId = selectedPriority?.priorityLevelId ?? ""
        if priorityId.isBlank { errorMsg = "No priority available."; return }
        let (startDt, endDt) = buildDatetimes(year: dateYear, month: dateMonth, day: dateDay,
                                              startHour: startHour, startMin: startMin,
                                              endHour: endHour, endMin: endMin)
        let repeatTypeName = selectedRepeatLabel.lowercased()
        let repeat_ = (repeatTypeName != "never" && repeatTypeName != "none") ? repeatTypeName : nil
        onSave(title.trimmingCharacters(in: .whitespaces),
               description.trimmingCharacters(in: .whitespaces),
               labelId, priorityId, startDt, endDt,
               location.trimmingCharacters(in: .whitespaces).nonBlank,
               selectedCandidate?.userId,
               repeat_)
    }
}

// ─────────────────────────────────────────────────────────────────
//  TO-DO DIALOG — title, description, due date, assign to only
// ─────────────────────────────────────────────────────────────────

struct TodoTaskDialog: View {

    var existingTask: TaskItem?
    var labels: [TaskLabel] = []
    let priorityLevels: [PriorityLevel]
    var showAssignTo: Bool = true
    var excludeUserId: String?
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void
    /// Same signature as the full dialogs: startDt = "{date}T00:00:00", endDt = "{date}T23:59:59"
    let onSave: TaskDialogSave

    @State private var title = ""
    @State private var description = ""
    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var errorMsg = ""
    @State private var candidates: [TaskAssignmentCandidate] = []
    @State private var candidatesLoading = false
    @State private var selectedCandidate: TaskAssignmentCandidate?
    @State private var selectedLabel: TaskLabel?
    @State private var showDeleteConfirm = false
    @State private var didInit = false

    private var isEdit: Bool { existingTask != nil }
    private var selectedPriority: PriorityLevel? {
        priorityLevels.first { $0.priorityLevel == 2 } ?? priorityLevels.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ZStack {
                    Text(isEdit ? "Edit To-Do" : "New To-Do")
                        .font(appFont(18, .bold))
                        .frame(maxWidth: .infinity)
                    if isEdit, onDelete != nil {
                        HStack {
                            Spacer()
                            Button { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(DangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 16)

                if let existingTask {
                    TaskStatusControls(task: existingTask, onChanged: onDismiss)
                    Spacer().frame(height: 12)
                }

                SDialogField(label: "Title", required: true) { SRoundedField(text: $title) }
                Spacer().frame(height: 12)
                SDialogField(label: "Description") {
                    SRoundedField(text: $description, singleLine: false, minLines: 3, maxLines: 5)
                }
                Spacer().frame(height: 12)

                // Due Date — date only, no time
                DateRow(label: "Due:", year: $dateYear, month: $dateMonth, day: $dateDay)

                if !labels.isEmpty {
                    Spacer().frame(height: 12)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category").font(appFont(12)).foregroundStyle(TextGray)
                        PillMenu(items: labels,
                                 title: { $0.label },
                                 noneLabel: "None",
                                 onSelect: { selectedLabel = $0 }) {
                            HStack {
                                Text(selectedLabel?.label ?? "None")
                                    .font(appFont(15)).foregroundStyle(TextDark)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundStyle(TextGray)
                            }
                            .padding(12)
                            .roundedBorder(BorderGray, 1, radius: 12)
                        }
                    }
                }

                if showAssignTo {
                    Spacer().frame(height: 12)
                    HStack(spacing: 0) {
                        Text("Assign to:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                        if candidatesLoading {
                            ProgressView().tint(AppGreen).frame(width: 20, height: 20)
                        } else if candidates.isEmpty {
                            Text("No candidates").font(appFont(13)).foregroundStyle(TextGray)
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
                }

                if errorMsg.isNotBlank {
                    Spacer().frame(height: 8)
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                }

                Spacer().frame(height: 20)

                SaveCancelRow(onSave: save, onCancel: onDismiss)
                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .alert("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This task will be permanently deleted.")
        }
        .task {
            guard !didInit else { return }
            didInit = true

            if let existingTask {
                title = existingTask.displayName == "Untitled" ? "" : existingTask.displayName
                description = existingTask.description ?? ""
                let start = splitDatetime(existingTask.startDatetime)
                dateYear = start.y; dateMonth = start.m; dateDay = start.d
                selectedLabel = labels.first { $0.labelId == existingTask.labelId }
            }

            if showAssignTo {
                candidatesLoading = true
                await AppRepository.getAssignmentCandidates(taskId: existingTask?.taskId).onSuccess { list in
                    let myId = TokenManager.getUserId()
                    candidates = list.filter {
                        $0.userId != myId
                            && $0.userId != excludeUserId
                            && !($0.displayName.isNullOrBlank)
                            && $0.displayName?.lowercased() != "string"
                            && $0.role?.lowercased() != "senior"
                    }
                    if selectedCandidate == nil {
                        selectedCandidate = existingTask?.assignedToUserId
                            .flatMap { id in candidates.first { $0.userId == id } }
                            ?? candidates.first { $0.offerStatus?.lowercased() == "accepted" }
                    }
                }
                candidatesLoading = false
            }
        }
    }

    private func save() {
        if title.isBlank { errorMsg = "Title is required."; return }
        guard let priorityId = selectedPriority?.priorityLevelId, priorityId.isNotBlank else {
            errorMsg = "No priority available."
            return
        }
        // Fall back to General Tasks if no category picked
        let labelId = selectedLabel?.labelId ?? todoLabelId
        let dateStr = (dateYear.isNotBlank && dateMonth.isNotBlank && dateDay.isNotBlank)
            ? "\(dateYear.padStart(4, "0"))-\(dateMonth.padStart(2, "0"))-\(dateDay.padStart(2, "0"))"
            : todayString()
        // Full day: start at 00:00, end at 23:59 so overdue fires at end of day
        onSave(title.trimmingCharacters(in: .whitespaces),
               description.trimmingCharacters(in: .whitespaces),
               labelId, priorityId,
               "\(dateStr)T00:00:00", "\(dateStr)T23:59:59",
               nil,                            // no location
               selectedCandidate?.userId,
               nil)                            // no repeat
    }
}

// ─────────────────────────────────────────────────────────────────
//  UNIFIED (FAMILY) TASK DIALOG — assigns to caregivers only
// ─────────────────────────────────────────────────────────────────

struct UnifiedTaskDialog: View {

    var existingTask: TaskItem?
    let labels: [TaskLabel]
    let priorityLevels: [PriorityLevel]
    var excludeUserId: String?
    var isTodo: Bool = false
    var hasRecurrence: Bool = false
    var currentRepeatTypeId: String?
    var onStopRepeating: (() -> Void)?
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void
    let onSave: TaskDialogSave

    @State private var taskTitle = ""
    @State private var description = ""
    @State private var location = ""
    @State private var errorMsg = ""
    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var startHour = ""
    @State private var startMin = ""
    @State private var endHour = ""
    @State private var endMin = ""
    @State private var selectedLabel: TaskLabel?
    @State private var selectedPriority: PriorityLevel?
    @State private var selectedRepeatLabel = "None"
    @State private var selectedRepeatTypeId: String?
    @State private var repeatOptions: [(String, String?)] = []
    @State private var repeatPreselected = false
    @State private var candidates: [TaskAssignmentCandidate] = []
    @State private var candidatesLoading = true
    @State private var selectedCandidate: TaskAssignmentCandidate?
    @State private var showDeleteConfirm = false
    @State private var didInit = false

    private var isEdit: Bool { existingTask != nil }
    private var relevantLabels: [TaskLabel] { isTodo ? [] : labels }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ZStack {
                    Text(isEdit ? "Edit Task" : "New Task")
                        .font(appFont(18, .bold))
                        .frame(maxWidth: .infinity)
                    if isEdit, onDelete != nil {
                        HStack {
                            Spacer()
                            Button { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(DangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 16)

                if let existingTask {
                    TaskStatusControls(task: existingTask, onChanged: onDismiss)
                    Spacer().frame(height: 12)
                }

                SDialogField(label: "Title", required: true) { SRoundedField(text: $taskTitle) }
                Spacer().frame(height: 12)
                SDialogField(label: "Description") {
                    SRoundedField(text: $description, singleLine: false, minLines: 3, maxLines: 5)
                }
                Spacer().frame(height: 12)
                DateRow(year: $dateYear, month: $dateMonth, day: $dateDay)
                Spacer().frame(height: 12)
                TimeRow(label: "Start:", labelWidth: 56, hour: $startHour, minute: $startMin)
                Spacer().frame(height: 8)
                TimeRow(label: "End:", labelWidth: 56, hour: $endHour, minute: $endMin)
                Spacer().frame(height: 12)
                SDialogField(label: "Location") { SRoundedField(text: $location) }

                if !relevantLabels.isEmpty {
                    Spacer().frame(height: 12)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category (optional)").font(appFont(12)).foregroundStyle(TextGray)
                        PillMenu(items: relevantLabels,
                                 title: { $0.label },
                                 noneLabel: "None (auto-detect)",
                                 onSelect: { selectedLabel = $0 }) {
                            HStack {
                                Text(selectedLabel?.label ?? "None (auto-detect)")
                                    .font(appFont(15)).foregroundStyle(TextDark)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundStyle(TextGray)
                            }
                            .padding(12)
                            .roundedBorder(BorderGray, 1, radius: 12)
                        }
                    }
                }

                Spacer().frame(height: 12)

                HStack(spacing: 0) {
                    Text("Repeat:").font(appFont(15, .bold)).frame(width: 80, alignment: .leading)
                    Menu {
                        ForEach(repeatOptions.indices, id: \.self) { index in
                            let option = repeatOptions[index]
                            Button(option.0) {
                                selectedRepeatLabel = option.0
                                selectedRepeatTypeId = option.1
                            }
                        }
                    } label: {
                        PillMenuLabel(text: selectedRepeatLabel, textColor: TextDark)
                    }
                }
                if selectedRepeatTypeId != nil {
                    Spacer().frame(height: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "repeat").font(.system(size: 12)).foregroundStyle(AppGreen)
                        Text("Repeats \(selectedRepeatLabel)").font(appFont(12)).foregroundStyle(AppGreen)
                    }
                }

                Spacer().frame(height: 12)

                HStack(spacing: 0) {
                    Text("Assign to:").font(appFont(15, .bold)).frame(width: 90, alignment: .leading)
                    if candidatesLoading {
                        ProgressView().tint(AppGreen).frame(width: 20, height: 20)
                    } else if candidates.isEmpty {
                        Text("No caregivers available").font(appFont(13)).foregroundStyle(TextGray)
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

                Spacer().frame(height: 20)

                SaveCancelRow(onSave: save, onCancel: onDismiss)
                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            if hasRecurrence, let onStopRepeating {
                Button("Delete future tasks", role: .destructive) { onStopRepeating() }
            }
            Button(hasRecurrence ? "Delete this task only" : "Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hasRecurrence
                 ? "This is a recurring task. What would you like to do?"
                 : "This task will be permanently deleted.")
        }
        .task {
            guard !didInit else { return }
            didInit = true

            if let existingTask {
                taskTitle = existingTask.displayName == "Untitled" ? "" : existingTask.displayName
                description = existingTask.description ?? ""
                location = existingTask.location ?? ""
                let start = splitDatetime(existingTask.startDatetime)
                dateYear = start.y; dateMonth = start.m; dateDay = start.d
                startHour = start.hh; startMin = start.mm
                let end = splitDatetime(existingTask.endDatetime)
                endHour = end.hh; endMin = end.mm
                selectedLabel = labels.first { $0.labelId == existingTask.labelId }
                selectedPriority = priorityLevels.first { $0.priorityLevelId == existingTask.priorityLevelId }
            }
            if selectedPriority == nil {
                selectedPriority = priorityLevels.first { $0.priorityLevel == 2 } ?? priorityLevels.first
            }

            repeatOptions = await loadRepeatOptions(includeNeverFirst: false, ordered: true)
            if !repeatPreselected, !repeatOptions.isEmpty, let currentRepeatTypeId,
               let match = repeatOptions.first(where: { $0.1 == currentRepeatTypeId }) {
                selectedRepeatLabel = match.0
                selectedRepeatTypeId = match.1
                repeatPreselected = true
            }

            candidatesLoading = true
            await AppRepository.getAssignmentCandidates().onSuccess { list in
                let myId = TokenManager.getUserId()
                // Family members can only assign to caregivers
                candidates = list.filter {
                    $0.userId != myId && $0.userId != excludeUserId
                        && !($0.displayName.isNullOrBlank)
                        && $0.displayName?.lowercased() != "string"
                        && ["caregiver", "professional caregiver"].contains($0.role?.lowercased() ?? "")
                }
                if selectedCandidate == nil {
                    selectedCandidate = existingTask?.assignedToUserId
                        .flatMap { id in candidates.first { $0.userId == id } }
                        ?? candidates.first { $0.offerStatus?.lowercased() == "accepted" }
                }
            }
            candidatesLoading = false
        }
    }

    private func save() {
        if taskTitle.isBlank { errorMsg = "Title is required."; return }
        let labelId = isTodo ? todoLabelId : (selectedLabel?.labelId ?? "")
        let priorityId = selectedPriority?.priorityLevelId ?? ""
        if priorityId.isBlank { errorMsg = "No priority available."; return }
        let (startDt, endDt) = buildDatetimes(year: dateYear, month: dateMonth, day: dateDay,
                                              startHour: startHour, startMin: startMin,
                                              endHour: endHour, endMin: endMin)
        let repeatTypeName = selectedRepeatLabel.lowercased()
        let repeat_ = (repeatTypeName != "none" && repeatTypeName != "never") ? repeatTypeName : nil
        onSave(taskTitle.trimmingCharacters(in: .whitespaces),
               description.trimmingCharacters(in: .whitespaces),
               labelId, priorityId, startDt, endDt,
               location.trimmingCharacters(in: .whitespaces).nonBlank,
               selectedCandidate?.userId,
               repeat_)
    }
}

// ─────────────────────────────────────────────────────────────────
//  CAREGIVER TASK DIALOG — no assign section
// ─────────────────────────────────────────────────────────────────

struct CaregiverTaskDialog: View {

    var existingTask: TaskItem?
    let labels: [TaskLabel]
    let priorityLevels: [PriorityLevel]
    var isTodo: Bool = false
    var hasRecurrence: Bool = false
    var currentRepeatTypeId: String?
    var onStopRepeating: (() -> Void)?
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void
    let onSave: CaregiverTaskDialogSave

    @State private var taskTitle = ""
    @State private var description = ""
    @State private var location = ""
    @State private var errorMsg = ""
    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var startHour = ""
    @State private var startMin = ""
    @State private var endHour = ""
    @State private var endMin = ""
    @State private var selectedLabel: TaskLabel?
    @State private var selectedPriority: PriorityLevel?
    @State private var selectedRepeatLabel = "None"
    @State private var selectedRepeatTypeId: String?
    @State private var repeatOptions: [(String, String?)] = []
    @State private var repeatPreselected = false
    @State private var showStopConfirm = false
    @State private var showDeleteConfirm = false
    @State private var didInit = false

    private var isEdit: Bool { existingTask != nil }
    private var relevantLabels: [TaskLabel] { isTodo ? [] : labels }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ZStack {
                    Text(isEdit ? "Edit Task" : "New Task")
                        .font(appFont(18, .bold))
                        .frame(maxWidth: .infinity)
                    if isEdit, onDelete != nil {
                        HStack {
                            Spacer()
                            Button { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(DangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 16)

                if let existingTask {
                    TaskStatusControls(task: existingTask, onChanged: onDismiss)
                    Spacer().frame(height: 12)
                }

                SDialogField(label: "Title", required: true) { SRoundedField(text: $taskTitle) }
                Spacer().frame(height: 12)
                SDialogField(label: "Description") {
                    SRoundedField(text: $description, singleLine: false, minLines: 3, maxLines: 5)
                }
                Spacer().frame(height: 12)
                DateRow(year: $dateYear, month: $dateMonth, day: $dateDay)
                Spacer().frame(height: 12)
                TimeRow(label: "Start:", labelWidth: 56, hour: $startHour, minute: $startMin)
                Spacer().frame(height: 8)
                TimeRow(label: "End:", labelWidth: 56, hour: $endHour, minute: $endMin)
                Spacer().frame(height: 12)
                SDialogField(label: "Location") { SRoundedField(text: $location) }

                if !relevantLabels.isEmpty {
                    Spacer().frame(height: 12)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category (optional)").font(appFont(12)).foregroundStyle(TextGray)
                        PillMenu(items: relevantLabels,
                                 title: { $0.label },
                                 noneLabel: "None (auto-detect)",
                                 onSelect: { selectedLabel = $0 }) {
                            HStack {
                                Text(selectedLabel?.label ?? "None (auto-detect)")
                                    .font(appFont(15)).foregroundStyle(TextDark)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundStyle(TextGray)
                            }
                            .padding(12)
                            .roundedBorder(BorderGray, 1, radius: 12)
                        }
                    }
                }

                Spacer().frame(height: 12)

                HStack(spacing: 0) {
                    Text("Repeat:").font(appFont(15, .bold)).frame(width: 80, alignment: .leading)
                    Menu {
                        ForEach(repeatOptions.indices, id: \.self) { index in
                            let option = repeatOptions[index]
                            Button(option.0) {
                                selectedRepeatLabel = option.0
                                selectedRepeatTypeId = option.1
                            }
                        }
                    } label: {
                        PillMenuLabel(text: selectedRepeatLabel, textColor: TextDark)
                    }
                }
                if selectedRepeatTypeId != nil {
                    Spacer().frame(height: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "repeat").font(.system(size: 12)).foregroundStyle(AppGreen)
                        Text("Repeats \(selectedRepeatLabel)").font(appFont(12)).foregroundStyle(AppGreen)
                    }
                }

                if isEdit && hasRecurrence && onStopRepeating != nil {
                    Spacer().frame(height: 12)
                    Button { showStopConfirm = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "repeat").font(.system(size: 15))
                            Text("Stop Repeating").font(appFont(14, .semibold))
                        }
                        .foregroundStyle(DangerRed)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .roundedBorder(DangerRed, 1.5, radius: 50)
                    }
                    .buttonStyle(.plain)
                }

                if errorMsg.isNotBlank {
                    Spacer().frame(height: 8)
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                }

                Spacer().frame(height: 20)

                SaveCancelRow(onSave: save, onCancel: onDismiss)
                Spacer().frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .alert("Stop Repeating?", isPresented: $showStopConfirm) {
            Button("Stop Repeating", role: .destructive) { onStopRepeating?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop future occurrences from being created.")
        }
        .alert("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This task will be permanently deleted.")
        }
        .task {
            guard !didInit else { return }
            didInit = true

            if let existingTask {
                taskTitle = existingTask.displayName == "Untitled" ? "" : existingTask.displayName
                description = existingTask.description ?? ""
                location = existingTask.location ?? ""
                let start = splitDatetime(existingTask.startDatetime)
                dateYear = start.y; dateMonth = start.m; dateDay = start.d
                startHour = start.hh; startMin = start.mm
                let end = splitDatetime(existingTask.endDatetime)
                endHour = end.hh; endMin = end.mm
                selectedLabel = labels.first { $0.labelId == existingTask.labelId }
                selectedPriority = priorityLevels.first { $0.priorityLevelId == existingTask.priorityLevelId }
            }
            if selectedPriority == nil {
                selectedPriority = priorityLevels.first { $0.priorityLevel == 2 } ?? priorityLevels.first
            }

            repeatOptions = await loadRepeatOptions(includeNeverFirst: false, ordered: true)
            if !repeatPreselected, !repeatOptions.isEmpty, let currentRepeatTypeId,
               let match = repeatOptions.first(where: { $0.1 == currentRepeatTypeId }) {
                selectedRepeatLabel = match.0
                selectedRepeatTypeId = match.1
                repeatPreselected = true
            }
        }
    }

    private func save() {
        if taskTitle.isBlank { errorMsg = "Title is required."; return }
        let labelId = isTodo ? todoLabelId : (selectedLabel?.labelId ?? "")
        let priorityId = selectedPriority?.priorityLevelId ?? ""
        if priorityId.isBlank { errorMsg = "No priority available."; return }
        let (startDt, endDt) = buildDatetimes(year: dateYear, month: dateMonth, day: dateDay,
                                              startHour: startHour, startMin: startMin,
                                              endHour: endHour, endMin: endMin)
        // Pass the repeat type as a lowercase NAME — the endpoint wants "weekly", not a UUID
        let repeatTypeName = selectedRepeatLabel.lowercased()
        let repeat_ = (repeatTypeName != "none" && repeatTypeName != "never") ? repeatTypeName : nil
        onSave(taskTitle.trimmingCharacters(in: .whitespaces),
               description.trimmingCharacters(in: .whitespaces),
               labelId, priorityId, startDt, endDt,
               location.trimmingCharacters(in: .whitespaces).nonBlank,
               repeat_)
    }
}
