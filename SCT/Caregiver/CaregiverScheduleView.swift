//
//  CaregiverScheduleView.swift
//  Port of caregiver/CaregiverScheduleScreen.kt (screen + CaregiverSectionHeader).
//  The caregiver screen reuses the family task cards, as on Android.
//

import SwiftUI

struct CaregiverScheduleView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = CaregiverScheduleViewModel()

    @State private var showAddDialog = false
    @State private var showAddTodoDialog = false
    @State private var editingTask: TaskItem?
    @State private var editScope: String?

    private var myUserId: String? { TokenManager.getUserId() }
    private var allTasks: [TaskItem] { vm.tasksState.data ?? [] }

    /// Labels that count as "Schedule" rather than "To Do", as on Android.
    private var scheduleLabelIds: [String] {
        vm.labels.filter { label in
            ["appointment", "errand", "social activity", "medication",
             "medication refills", "daily routine", "chores"]
                .contains(label.label.lowercased())
        }
        .compactMap(\.labelId)
    }

    private var allScheduleItems: [TaskItem] {
        allTasks
            .filter { $0.labelId != nil && scheduleLabelIds.contains($0.labelId!) }
            .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }
    }
    private var allTodoItems: [TaskItem] {
        allTasks.filter { $0.labelId == nil || !scheduleLabelIds.contains($0.labelId!) }
    }
    private var scheduleItems: [TaskItem] {
        vm.showAllSchedule ? allScheduleItems : Array(allScheduleItems.prefix(5))
    }
    private var todoItems: [TaskItem] {
        vm.showAllTodo ? allTodoItems : Array(allTodoItems.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            CaregiverBottomNavBar(current: "schedules", onNavigate: onNavigate)
        }
        .sheet(isPresented: $showAddDialog) {
            CaregiverTaskDialog(
                existingTask: nil, labels: vm.labels, priorityLevels: vm.priorityLevels, isTodo: false,
                onDismiss: { showAddDialog = false },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, repeatTypeName in
                    vm.createTask(title: title, description: desc, labelId: labelId,
                                  priorityLevelId: priorityId, startDatetime: startDt,
                                  endDatetime: endDt, location: location,
                                  repeatTypeName: repeatTypeName)
                    showAddDialog = false
                }
            )
        }
        .sheet(isPresented: $showAddTodoDialog) {
            TodoTaskDialog(
                existingTask: nil, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: false,
                onDismiss: { showAddTodoDialog = false },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, _, repeatTypeName in
                    vm.createTask(title: title, description: desc, labelId: labelId,
                                  priorityLevelId: priorityId, startDatetime: startDt,
                                  endDatetime: endDt, location: location,
                                  repeatTypeName: repeatTypeName)
                    showAddTodoDialog = false
                }
            )
        }
        .sheet(item: $editingTask) { task in
            editSheet(for: task)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.tasksState {
        case .loading:
            VStack { Spacer(); ProgressView().tint(AppGreen); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBg)

        case .error(let message):
            VStack { Spacer(); ErrorRetry(message: message) { vm.loadTasks() }; Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBg)

        default:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Spacer().frame(height: 8)
                    ExpandableTaskSectionHeader(
                        title: "Schedule", expanded: vm.showAllSchedule,
                        onToggle: { vm.toggleShowAllSchedule() },
                        onAdd: { showAddDialog = true })

                    if scheduleItems.isEmpty {
                        Text("No upcoming schedule items.")
                            .font(appFont(14)).foregroundStyle(TextGray)
                            .padding(.vertical, 8)
                    }
                    ForEach(scheduleItems) { task in
                        let offer = vm.offersMap[task.taskId]
                        FamilyScheduleTaskCard(
                            task: task, offer: offer,
                            isAssignedToMe: offer?.toUserId == myUserId,
                            onEdit: { startEdit(task) },
                            onComplete: { vm.deleteTask(taskId: task.taskId) },
                            onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                            onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                        )
                    }
                    ExpandableTaskSectionHeader(
                        title: "To Do List", expanded: vm.showAllTodo,
                        onToggle: { vm.toggleShowAllTodo() },
                        onAdd: { showAddTodoDialog = true })

                    if todoItems.isEmpty {
                        Text("No upcoming to-do items.")
                            .font(appFont(14)).foregroundStyle(TextGray)
                            .padding(.vertical, 8)
                    }
                    ForEach(todoItems) { task in
                        let offer = vm.offersMap[task.taskId]
                        FamilyTodoTaskCard(
                            task: task, offer: offer,
                            isAssignedToMe: offer?.toUserId == myUserId,
                            onEdit: { startEdit(task) },
                            onComplete: { vm.deleteTask(taskId: task.taskId) },
                            onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                            onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                        )
                    }
                    Spacer().frame(height: 8)
                    MessageEldaBar { onNavigate("caregiver_aichat/caregiver_schedule") }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }
            .background(AppBg)
            .refreshable { vm.loadTasks() }
        }
    }

    @ViewBuilder
    private func editSheet(for task: TaskItem) -> some View {
        let taskId = task.taskId
        let hasRecurrence = vm.recurrenceMap[taskId] != nil
        let isTodoTask = task.labelId == todoLabelId

        if hasRecurrence && !isTodoTask && editScope == nil {
            RecurringEditScopeDialog(
                includeForward: true,
                onPick: { editScope = $0 },
                onCancel: { editingTask = nil; editScope = nil }
            )
        } else if isTodoTask {
            TodoTaskDialog(
                existingTask: task, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: false,
                onDelete: { vm.deleteTask(taskId: taskId); editingTask = nil },
                onDismiss: { editingTask = nil },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, assignTo, _ in
                    vm.updateTask(taskId: taskId, title: title, description: desc, labelId: labelId,
                                  priorityLevelId: priorityId, startDatetime: startDt,
                                  endDatetime: endDt, location: location, assignToUserId: assignTo)
                    editingTask = nil
                }
            )
        } else {
            CaregiverTaskDialog(
                existingTask: task,
                labels: vm.labels,
                priorityLevels: vm.priorityLevels,
                hasRecurrence: hasRecurrence,
                currentRepeatTypeId: vm.recurrenceTypeMap[taskId],
                onStopRepeating: { vm.stopRepeating(taskId: taskId) { editingTask = nil } },
                onDelete: { vm.deleteTask(taskId: taskId); editingTask = nil },
                onDismiss: { editingTask = nil; editScope = nil },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, repeatTypeName in
                    switch editScope {
                    case "all":
                        vm.updateAllRepeatedTasks(taskId: taskId, title: title, description: desc,
                                                  labelId: labelId, priorityLevelId: priorityId,
                                                  startDatetime: startDt, endDatetime: endDt,
                                                  location: location, fromDatetime: nil)
                    case "forward":
                        vm.updateAllRepeatedTasks(taskId: taskId, title: title, description: desc,
                                                  labelId: labelId, priorityLevelId: priorityId,
                                                  startDatetime: startDt, endDatetime: endDt,
                                                  location: location, fromDatetime: task.startDatetime)
                    default:
                        vm.updateTask(taskId: taskId, title: title, description: desc, labelId: labelId,
                                      priorityLevelId: priorityId, startDatetime: startDt,
                                      endDatetime: endDt, location: location,
                                      assignToUserId: nil, repeatTypeName: repeatTypeName)
                    }
                    editingTask = nil
                    editScope = nil
                }
            )
        }
    }

    private func startEdit(_ task: TaskItem) {
        let sourceId = task.parentTaskId ?? task.taskId
        vm.loadRecurrenceForTask(taskId: sourceId)
        editScope = nil
        editingTask = task
    }

    private func seeAllButton(expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(expanded ? "Show Less" : "See All")
                .font(appFont(14, .medium))
                .foregroundStyle(AppGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// ── Section header ────────────────────────────────────────────────

struct CaregiverSectionHeader: View {
    let title: String
    let onAdd: () -> Void

    var body: some View {
        SectionHeader(title: title, onAdd: onAdd)
    }
}
