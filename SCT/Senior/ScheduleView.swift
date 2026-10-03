//
//  ScheduleView.swift
//  Port of senior/ScheduleScreen.kt.
//

import SwiftUI

struct ScheduleView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = ScheduleViewModel()

    @State private var showAddDialog = false
    @State private var showAddTodoDialog = false
    @State private var editingTask: TaskItem?
    @State private var editScope: String?

    private var myUserId: String? { TokenManager.getUserId() }

    private var allScheduleItems: [TaskItem] { vm.scheduleState.data ?? [] }
    private var allTodoItems: [TaskItem] { vm.todoState.data ?? [] }
    private var scheduleItems: [TaskItem] {
        vm.showAllSchedule ? allScheduleItems : Array(allScheduleItems.prefix(5))
    }
    private var todoItems: [TaskItem] {
        vm.showAllTodo ? allTodoItems : Array(allTodoItems.prefix(5))
    }
    private var errorMsg: String? {
        vm.scheduleState.errorMessage ?? vm.todoState.errorMessage
    }
    private var isLoading: Bool { vm.scheduleState.isLoading || vm.todoState.isLoading }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(TextDark)
                        .padding(8)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.leading, 4)

            if let errorMsg {
                Spacer()
                ErrorRetry(message: errorMsg) { vm.loadTasks() }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ExpandableTaskSectionHeader(
                            title: "Schedule", expanded: vm.showAllSchedule,
                            onToggle: { vm.toggleShowAllSchedule() },
                            onAdd: { showAddDialog = true })

                        if scheduleItems.isEmpty {
                            Text("No schedule items yet. Tap + to add one.")
                                .font(appFont(14)).foregroundStyle(TextGray)
                                .padding(.vertical, 8)
                        }
                        ForEach(scheduleItems) { task in
                            let offer = vm.offersMap[task.taskId]
                            ScheduleTaskCard(
                                task: task, offer: offer,
                                isAssignedToMe: offer?.toUserId == myUserId,
                                onEdit: { startEdit(task) },
                                onComplete: { vm.completeTask(taskId: task.taskId) },
                                onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                                onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                            )
                        }
                        ExpandableTaskSectionHeader(
                            title: "To Do List", expanded: vm.showAllTodo,
                            onToggle: { vm.toggleShowAllTodo() },
                            onAdd: { showAddTodoDialog = true })

                        if todoItems.isEmpty {
                            Text("No to-do items yet. Tap + to add one.")
                                .font(appFont(14)).foregroundStyle(TextGray)
                                .padding(.vertical, 8)
                        }
                        ForEach(todoItems) { task in
                            let offer = vm.offersMap[task.taskId]
                            TodoTaskCard(
                                task: task, offer: offer,
                                isAssignedToMe: offer?.toUserId == myUserId,
                                onEdit: { startEdit(task) },
                                onComplete: { vm.completeTask(taskId: task.taskId) },
                                onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                                onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                            )
                        }
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 16)
                }
                .refreshable { vm.loadTasks() }
            }

            MessageEldaBar { onNavigate("aichat/schedule") }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(AppBg)
        .sheet(isPresented: $showAddDialog) {
            SeniorNewTaskDialog(
                existingTask: nil, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: true, isTodo: false,
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
                showAssignTo: true,
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
    private func editSheet(for task: TaskItem) -> some View {
        let taskId = task.taskId
        // Instant detection from task fields; recurrenceMap confirms once the async call returns
        let hasRecurrence = vm.recurrenceMap[taskId] != nil
            || task.isRepeatable == true
            || task.recurrenceRuleId != nil
            || (task.parentTaskId != nil && task.parentTaskId != taskId)
        let isTodoTask = task.labelId == todoLabelId

        if hasRecurrence && !isTodoTask && editScope == nil {
            // Scope picker comes first for recurring tasks
            RecurringEditScopeDialog(
                includeForward: true,
                onPick: { editScope = $0 },
                onCancel: { editingTask = nil; editScope = nil }
            )
        } else if isTodoTask {
            TodoTaskDialog(
                existingTask: task, labels: vm.labels, priorityLevels: vm.priorityLevels,
                showAssignTo: true,
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
            SeniorNewTaskDialog(
                existingTask: task,
                labels: vm.labels,
                priorityLevels: vm.priorityLevels,
                showAssignTo: true,
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
        let sourceId = task.parentTaskId ?? task.taskId
        vm.loadRecurrenceForTask(lookupId: task.taskId, sourceId: sourceId)
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
