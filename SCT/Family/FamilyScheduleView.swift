//
//  FamilyScheduleView.swift
//  Port of family/FamilyScheduleScreen.kt (screen + FamilySectionHeader).
//

import SwiftUI

struct FamilyScheduleView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = FamilyScheduleViewModel()

    @State private var showAddDialog = false
    @State private var showAddTodoDialog = false
    @State private var editingTask: TaskItem?
    @State private var editScope: String?

    private var myUserId: String? { TokenManager.getUserId() }
    private var seniorId: String? { TokenManager.getSeniorUserId() }

    private var allScheduleItems: [TaskItem] { vm.scheduleState.data ?? [] }
    private var allTodoItems: [TaskItem] { vm.todoState.data ?? [] }
    private var scheduleItems: [TaskItem] {
        vm.showAllSchedule ? allScheduleItems : Array(allScheduleItems.prefix(5))
    }
    private var todoItems: [TaskItem] {
        vm.showAllTodo ? allTodoItems : Array(allTodoItems.prefix(5))
    }
    private var anyLoading: Bool { vm.scheduleState.isLoading || vm.todoState.isLoading }
    private var errorMsg: String? { vm.scheduleState.errorMessage ?? vm.todoState.errorMessage }

    var body: some View {
        VStack(spacing: 0) {
            content
            FamilyBottomNavBar(current: "schedules", onNavigate: onNavigate)
        }
        .sheet(isPresented: $showAddDialog) {
            UnifiedTaskDialog(
                existingTask: nil, labels: vm.labels, priorityLevels: vm.priorityLevels,
                excludeUserId: seniorId, isTodo: false,
                onDismiss: { showAddDialog = false },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, assignTo, repeatTypeName in
                    vm.createTask(title: title, description: desc, labelId: labelId,
                                  priorityLevelId: priorityId, startDatetime: startDt,
                                  endDatetime: endDt, location: location,
                                  assignToUserId: assignTo, repeatTypeName: repeatTypeName)
                    showAddDialog = false
                }
            )
        }
        .sheet(isPresented: $showAddTodoDialog) {
            TodoTaskDialog(
                existingTask: nil, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: true, excludeUserId: seniorId,
                onDismiss: { showAddTodoDialog = false },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, assignTo, repeatTypeName in
                    vm.createTask(title: title, description: desc, labelId: labelId,
                                  priorityLevelId: priorityId, startDatetime: startDt,
                                  endDatetime: endDt, location: location,
                                  assignToUserId: assignTo, repeatTypeName: repeatTypeName)
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
        if anyLoading && allScheduleItems.isEmpty && allTodoItems.isEmpty {
            VStack { Spacer(); ProgressView().tint(AppGreen); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBg)
        } else if let errorMsg {
            VStack { Spacer(); ErrorRetry(message: errorMsg) { vm.loadTasks() }; Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBg)
        } else {
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
                    MessageEldaBar { onNavigate("family_aichat/family_schedule") }
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
        // Use task fields for instant detection; recurrenceMap confirms once loaded
        let hasRecurrence = vm.recurrenceMap[taskId] != nil
            || task.isRepeatable == true
            || task.recurrenceRuleId != nil
            || (task.parentTaskId != nil && task.parentTaskId != taskId)
        let isTodoTask = task.labelId == todoLabelId

        if hasRecurrence && !isTodoTask && editScope == nil {
            // The family screen offers only "this task" / "all tasks"
            RecurringEditScopeDialog(
                includeForward: false,
                onPick: { editScope = $0 },
                onCancel: { editingTask = nil; editScope = nil }
            )
        } else if isTodoTask {
            TodoTaskDialog(
                existingTask: task, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: true, excludeUserId: seniorId,
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
            UnifiedTaskDialog(
                existingTask: task,
                labels: vm.labels,
                priorityLevels: vm.priorityLevels,
                excludeUserId: seniorId,
                hasRecurrence: hasRecurrence,
                currentRepeatTypeId: vm.recurrenceTypeMap[taskId],
                onStopRepeating: { vm.stopRepeating(taskId: taskId) { editingTask = nil } },
                onDelete: { vm.deleteTask(taskId: taskId); editingTask = nil },
                onDismiss: { editingTask = nil; editScope = nil },
                onSave: { title, desc, labelId, priorityId, startDt, endDt, location, assignTo, repeatTypeName in
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
                                      assignToUserId: assignTo, repeatTypeName: repeatTypeName)
                    }
                    editingTask = nil
                    editScope = nil
                }
            )
        }
    }

    private func startEdit(_ task: TaskItem) {
        vm.loadRecurrenceForTask(taskId: task.taskId)
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

struct FamilySectionHeader: View {
    let title: String
    let onAdd: () -> Void

    var body: some View {
        SectionHeader(title: title, onAdd: onAdd)
    }
}
