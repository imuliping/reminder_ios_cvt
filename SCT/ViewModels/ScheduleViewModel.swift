//
//  ScheduleViewModel.swift
//  Port of senior/ScheduleViewModel.kt.
//

import Foundation
import Combine

@MainActor
final class ScheduleViewModel: ObservableObject {

    @Published var scheduleState: UiState<[TaskItem]> = .idle
    @Published var todoState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    @Published var labels: [TaskLabel] = []
    @Published var priorityLevels: [PriorityLevel] = []
    @Published var recurrenceMap: [String: String] = [:]
    @Published var recurrenceTypeMap: [String: String] = [:]
    @Published var showAllSchedule = false
    @Published var showAllTodo = false

    private var cancellables = Set<AnyCancellable>()

    // Only fetch from network when expanding; collapsing trims client-side instantly
    func toggleShowAllSchedule() {
        showAllSchedule.toggle()
        if showAllSchedule { loadTasks() }
    }

    func toggleShowAllTodo() {
        showAllTodo.toggle()
        if showAllTodo { loadTasks() }
    }

    init() {
        Task {
            async let lookup: Void = loadLookupData()
            async let tasks: Void = loadTasksAsync()
            _ = await (lookup, tasks)
        }
        observeScheduleRefresh()
    }

    func loadTasks() {
        Task { await loadTasksAsync() }
    }

    private func loadTasksAsync() async {
        scheduleState = .loading
        todoState = .loading

        let myUserId = TokenManager.getUserId() ?? ""

        let scheduleTasks = showAllSchedule
            ? await AppRepository.getScheduleTasks(subjectUserId: myUserId).getOrElse([])
            : await AppRepository.getUpcomingScheduleTasks(subjectUserId: myUserId).getOrElse([])

        let todoTasks = showAllTodo
            ? await AppRepository.getTodoListTasks(subjectUserId: myUserId).getOrElse([])
            : await AppRepository.getUpcomingTodoListTasks(subjectUserId: myUserId).getOrElse([])

        let allTaskIds = Array(Set((scheduleTasks + todoTasks).map(\.taskId)))
        offersMap = await loadOffersMap(taskIds: allTaskIds)

        let todayPrefix = todayString()
        let expanded = showAllSchedule
        func isUpcoming(_ task: TaskItem) -> Bool {
            if expanded { return true }
            guard let dt = task.startDatetime ?? task.endDatetime else { return true }
            return dt.take(10) >= todayPrefix
        }

        scheduleState = .success(
            scheduleTasks.filter(isUpcoming).filterJunk().filterNotCompleted()
        )
        todoState = .success(
            todoTasks.filterJunk().filterNotCompleted()
        )
    }

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadTasks() }
            .store(in: &cancellables)
    }

    func loadRecurrenceForTask(lookupId: String, sourceId: String? = nil) {
        let source = sourceId ?? lookupId
        Task {
            await AppRepository.getRecurrenceRulesForTask(taskId: source).onSuccess { rules in
                if let activeRule = rules.first(where: { $0.isActive }) {
                    recurrenceMap[lookupId] = activeRule.recurrenceRuleId
                    recurrenceTypeMap[lookupId] = activeRule.repeatTypeId
                }
            }
        }
    }

    func stopRepeating(taskId: String, onDone: @escaping () -> Void) {
        Task {
            await AppRepository.stopFutureRepeatedTasks(taskId: taskId)
                .onSuccess { _ in
                    recurrenceMap.removeValue(forKey: taskId)
                    recurrenceTypeMap.removeValue(forKey: taskId)
                    LogManager.logInfo("Future repeated tasks deleted for \(taskId)")
                    onDone()
                }
                .onFailure { LogManager.logError("stopFutureRepeatedTasks failed: \($0.message)") }
        }
    }

    func createTask(title: String, description: String, labelId: String, priorityLevelId: String,
                    startDatetime: String, endDatetime: String, location: String?,
                    assignToUserId: String? = nil, repeatTypeName: String? = nil) {
        Task {
            let myUserId = TokenManager.getUserId()
            let taskResult: Result<TaskItem, Error>
            if let repeatTypeName, repeatTypeName.isNotBlank {
                taskResult = await AppRepository.createTaskWithRecurrence(
                    title: title, description: description.nonBlank, labelId: labelId,
                    priorityLevelId: priorityLevelId, startDatetime: startDatetime,
                    endDatetime: endDatetime, location: location,
                    subjectUserId: myUserId, repeatTypeName: repeatTypeName)
            } else {
                taskResult = await AppRepository.createTask(
                    title: title, description: description.nonBlank, labelId: labelId,
                    priorityLevelId: priorityLevelId, startDatetime: startDatetime,
                    endDatetime: endDatetime, location: location)
            }

            await taskResult.fold(
                onSuccess: { task in
                    LogManager.logInfo("createTask success — taskId=\(task.taskId)")
                    if let myUserId {
                        await AppRepository.assignTaskToUser(taskId: task.taskId, userId: myUserId,
                                                            taskRoleId: RoleIds.SENIOR)
                            .onFailure { LogManager.logError("self-assign failed: \($0.message)") }
                    }
                    if let assignToUserId {
                        await AppRepository.createAssignmentOffer(
                            taskId: task.taskId, toUserId: assignToUserId,
                            message: "You've been assigned: \(title)")
                            .onFailure { LogManager.logError("createAssignmentOffer failed: \($0.message)") }
                    }
                    await loadTasksAsync()
                    NotificationEventBus.shared.triggerScheduleRefresh()
                },
                onFailure: { LogManager.logError("createTask failed: \($0.message)") }
            )
        }
    }

    func updateTask(taskId: String, title: String, description: String, labelId: String,
                    priorityLevelId: String, startDatetime: String, endDatetime: String,
                    location: String?, assignToUserId: String? = nil, repeatTypeName: String? = nil) {
        Task {
            let result: Result<TaskItem, Error>
            if let repeatTypeName, repeatTypeName.isNotBlank {
                result = await AppRepository.updateTaskWithRecurrence(
                    taskId: taskId, title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityLevelId,
                    startDatetime: startDatetime, endDatetime: endDatetime,
                    location: location, repeatTypeName: repeatTypeName)
            } else {
                result = await AppRepository.updateTask(
                    taskId: taskId, title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityLevelId,
                    startDatetime: startDatetime, endDatetime: endDatetime, location: location)
            }

            await result.fold(
                onSuccess: { _ in
                    if let assignToUserId {
                        let existing = await AppRepository.getOffersForTask(taskId: taskId).getOrNull ?? []
                        for offer in existing where ["PENDING", "ACCEPTED"].contains(offer.status?.uppercased() ?? "") {
                            _ = await AppRepository.cancelOffer(offerId: offer.offerId)
                        }
                        await AppRepository.createAssignmentOffer(
                            taskId: taskId, toUserId: assignToUserId,
                            message: "You've been assigned: \(title)")
                            .onFailure { LogManager.logError("createAssignmentOffer failed: \($0.message)") }
                    }
                    recurrenceMap.removeValue(forKey: taskId)
                    recurrenceTypeMap.removeValue(forKey: taskId)
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("updateTask failed: \($0.message)") }
            )
        }
    }

    /// fromDatetime = nil  → update ALL instances (past + future)
    /// fromDatetime = <dt> → update only from that datetime forward
    func updateAllRepeatedTasks(taskId: String, title: String, description: String, labelId: String,
                                priorityLevelId: String, startDatetime: String, endDatetime: String,
                                location: String?, fromDatetime: String? = nil) {
        Task {
            await AppRepository.updateRepeatedTasks(
                taskId: taskId, title: title, description: description.nonBlank,
                labelId: labelId, priorityLevelId: priorityLevelId,
                startDatetime: startDatetime, endDatetime: endDatetime,
                location: location, fromDatetime: fromDatetime
            ).fold(
                onSuccess: { _ in
                    recurrenceMap.removeValue(forKey: taskId)
                    recurrenceTypeMap.removeValue(forKey: taskId)
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("updateAllRepeatedTasks failed: \($0.message)") }
            )
        }
    }

    func deleteTask(taskId: String) {
        Task {
            await AppRepository.deleteTask(taskId: taskId).fold(
                onSuccess: { _ in await loadTasksAsync() },
                onFailure: {
                    LogManager.logError("deleteTask failed: \($0.message)")
                    await loadTasksAsync()
                }
            )
        }
    }

    func completeTask(taskId: String) {
        Task {
            await AppRepository.completeTask(taskId: taskId).fold(
                onSuccess: { _ in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("completeTask failed: \($0.message)") }
            )
        }
    }

    func acceptOffer(offerId: String) {
        Task { await AppRepository.acceptOffer(offerId: offerId).onSuccess { _ in await loadTasksAsync() } }
    }

    func declineOffer(offerId: String) {
        Task { await AppRepository.declineOffer(offerId: offerId).onSuccess { _ in await loadTasksAsync() } }
    }

    private func loadLookupData() async {
        async let labelsResult = AppRepository.getLabels()
        async let priorityResult = AppRepository.getPriorityLevels()
        await labelsResult.onSuccess { labels = $0 }
        await priorityResult.onSuccess { priorityLevels = $0 }
    }
}
