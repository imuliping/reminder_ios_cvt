//
//  FamilyViewModels.swift
//  Ports of FamilyHomeViewModel (family/FamilyHomeScreen.kt),
//  FamilyScheduleViewModel (family/FamilyScheduleScreen.kt),
//  SuperviseViewModel (family/FamilySuperviseScreen.kt) and
//  ReportViewModel (family/FamilyReportScreen.kt).
//

import Foundation
import Combine

// ── Family Home ───────────────────────────────────────────────────

@MainActor
final class FamilyHomeViewModel: ObservableObject {

    @Published var tasksState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    /// Offers assigned TO this family member (pending only, for the banner).
    @Published var offersForMe: [TaskAssignmentOffer] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadUpcomingTasks()
        observeScheduleRefresh()
    }

    func loadUpcomingTasks() {
        Task {
            tasksState = .loading
            let allTasks = await AppRepository.getUpcomingScheduleTasks().getOrElse([])
            let offers = await loadOffersMap(taskIds: allTasks.map(\.taskId))
            offersMap = offers

            var seen = Set<String>()
            let merged = allTasks
                .filter { seen.insert($0.taskId).inserted }
                .filterJunk()
                .filter { !($0.startDatetime.isNullOrEmpty) }
                .filterNotCompleted()
                .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }
                .prefix(3)

            tasksState = .success(Array(merged))

            // Also load pending offers directed at this family member
            await AppRepository.getMyOffers(status: "PENDING").onSuccess { pending in
                offersForMe = pending.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            }
        }
    }

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadUpcomingTasks() }
            .store(in: &cancellables)
    }
}

// ── Family Schedule ───────────────────────────────────────────────

@MainActor
final class FamilyScheduleViewModel: ObservableObject {

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

    func loadTasks() { Task { await loadTasksAsync() } }

    private func loadTasksAsync() async {
        scheduleState = .loading
        todoState = .loading
        async let scheduleD: [TaskItem] = showAllSchedule
            ? AppRepository.getScheduleTasks(unfiltered: true).getOrElse([])
            : AppRepository.getUpcomingScheduleTasks().getOrElse([])
        async let todoD: [TaskItem] = showAllTodo
            ? AppRepository.getTodoListTasks(unfiltered: true).getOrElse([])
            : AppRepository.getUpcomingTodoListTasks().getOrElse([])

        let allScheduleTasks = await scheduleD
        let allTodoTasks = await todoD
        let familyTasks = await AppRepository.getMyFamilyTasks().getOrElse([])

        var seenAll = Set<String>()
        let allTasksRaw = (allScheduleTasks + familyTasks + allTodoTasks)
            .filter { seenAll.insert($0.taskId).inserted }
        let offers = await loadOffersMap(taskIds: allTasksRaw.map(\.taskId))
        offersMap = offers

        let todayPrefix = todayString()
        let expanded = showAllSchedule

        func isUpcoming(_ task: TaskItem) -> Bool {
            if expanded { return true }
            guard let dt = task.startDatetime ?? task.endDatetime else { return true }
            return dt.take(10) >= todayPrefix
        }

        var seenSchedule = Set<String>()
        let schedule = (allScheduleTasks + familyTasks)
            .filter(isUpcoming)
            .filter { seenSchedule.insert($0.taskId).inserted }
            .filterJunk()
            .filterNotCompleted()
            .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }

        var seenTodo = Set<String>()
        let todo = allTodoTasks
            .filter { seenTodo.insert($0.taskId).inserted }
            .filterJunk()
            .filterNotCompleted()

        scheduleState = .success(schedule)
        todoState = .success(todo)
    }

    func loadRecurrenceForTask(taskId: String) {
        Task {
            await AppRepository.getRecurrenceRulesForTask(taskId: taskId).onSuccess { rules in
                if let activeRule = rules.first(where: { $0.isActive }) {
                    recurrenceMap[taskId] = activeRule.recurrenceRuleId
                    recurrenceTypeMap[taskId] = activeRule.repeatTypeId
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
                    await loadTasksAsync()
                    onDone()
                }
                .onFailure { LogManager.logError("stopFutureRepeatedTasks failed: \($0.message)") }
        }
    }

    func createTask(title: String, description: String, labelId: String, priorityLevelId: String,
                    startDatetime: String, endDatetime: String, location: String?,
                    assignToUserId: String?, repeatTypeName: String? = nil) {
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
                    endDatetime: endDatetime, location: location, subjectUserId: myUserId)
            }

            await taskResult.fold(
                onSuccess: { task in
                    if let myUserId {
                        await AppRepository.assignTaskToUser(taskId: task.taskId, userId: myUserId,
                                                            taskRoleId: RoleIds.FAMILY)
                            .onFailure { LogManager.logError("family self-assign failed: \($0.message)") }
                    }
                    if let assignToUserId {
                        await AppRepository.createAssignmentOffer(
                            taskId: task.taskId, toUserId: assignToUserId,
                            message: "You've been assigned: \(title)")
                            .onFailure { LogManager.logError("createAssignmentOffer failed: \($0.message)") }
                    }
                    await loadTasksAsync()
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
                    // Update assignment if changed
                    if let assignToUserId {
                        let existing = await AppRepository.getOffersForTask(taskId: taskId).getOrNull ?? []
                        for offer in existing where ["PENDING", "ACCEPTED"].contains(offer.status?.uppercased() ?? "") {
                            _ = await AppRepository.cancelOffer(offerId: offer.offerId)
                        }
                        _ = await AppRepository.createAssignmentOffer(
                            taskId: taskId, toUserId: assignToUserId,
                            message: "You've been assigned: \(title)")
                    }
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("updateTask failed: \($0.message)") }
            )
        }
    }

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
                onSuccess: { _ in await loadTasksAsync() },
                onFailure: { LogManager.logError("updateRepeatedTasks failed: \($0.message)") }
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

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadTasks() }
            .store(in: &cancellables)
    }
}

// ── Supervise (family member viewing the senior's schedule) ────────

@MainActor
final class SuperviseViewModel: ObservableObject {

    @Published var tasksState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    @Published var labels: [TaskLabel] = []
    @Published var priorityLevels: [PriorityLevel] = []
    @Published var recurrenceMap: [String: String] = [:]
    @Published var recurrenceTypeMap: [String: String] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        Task { await loadLookupData() }
        loadTasks()
        observeScheduleRefresh()
    }

    func loadTasks() { Task { await loadTasksAsync() } }

    private func loadTasksAsync() async {
        tasksState = .loading

        var seniorId = TokenManager.getSeniorUserId()
        if seniorId == nil {
            seniorId = await AppRepository.getMySeniors().getOrNull?.first?.userId
            if let seniorId { TokenManager.saveSeniorUserId(seniorId) }
        }
        guard let seniorId else {
            tasksState = .error("No linked senior found")
            return
        }

        let fromDt = dayOffsetString(-30)
        let toDt   = dayOffsetString(90)

        await AppRepository.getTasks(subjectUserId: seniorId, fromDt: fromDt, toDt: toDt).fold(
            onSuccess: { tasks in
                let candidates = tasks.filterJunk().filter { !($0.startDatetime.isNullOrEmpty) }
                let offers = await loadOffersMap(taskIds: candidates.map(\.taskId))
                offersMap = offers

                let sorted = candidates
                    .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }

                tasksState = .success(sorted)
            },
            onFailure: { tasksState = .error($0.message.isEmpty ? "Failed to load tasks" : $0.message) }
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
                    await loadTasksAsync()
                    onDone()
                }
                .onFailure { LogManager.logError("stopFutureRepeatedTasks failed: \($0.message)") }
        }
    }

    func completeTask(taskId: String) {
        Task { await AppRepository.completeTask(taskId: taskId).onSuccess { _ in await loadTasksAsync() } }
    }

    func acceptOffer(offerId: String) {
        Task { await AppRepository.acceptOffer(offerId: offerId).onSuccess { _ in await loadTasksAsync() } }
    }

    func declineOffer(offerId: String) {
        Task { await AppRepository.declineOffer(offerId: offerId).onSuccess { _ in await loadTasksAsync() } }
    }

    func createTask(title: String, description: String, labelId: String, priorityLevelId: String,
                    startDatetime: String, endDatetime: String, location: String?,
                    assignToUserId: String?, repeatTypeName: String? = nil) {
        Task {
            let taskResult: Result<TaskItem, Error>
            if let repeatTypeName, repeatTypeName.isNotBlank {
                taskResult = await AppRepository.createTaskWithRecurrence(
                    title: title, description: description.nonBlank, labelId: labelId,
                    priorityLevelId: priorityLevelId, startDatetime: startDatetime,
                    endDatetime: endDatetime, location: location,
                    subjectUserId: TokenManager.getSeniorUserId(), repeatTypeName: repeatTypeName)
            } else {
                taskResult = await AppRepository.createTask(
                    title: title, description: description.nonBlank, labelId: labelId,
                    priorityLevelId: priorityLevelId, startDatetime: startDatetime,
                    endDatetime: endDatetime, location: location)
            }

            await taskResult.fold(
                onSuccess: { task in
                    if let assignToUserId {
                        _ = await AppRepository.createAssignmentOffer(
                            taskId: task.taskId, toUserId: assignToUserId,
                            message: "You've been assigned: \(title)")
                    }
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("createTask failed: \($0.message)") }
            )
        }
    }

    func updateTask(taskId: String, title: String, description: String, labelId: String,
                    priorityLevelId: String, startDatetime: String, endDatetime: String,
                    location: String?, repeatTypeName: String? = nil) {
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
                    recurrenceMap.removeValue(forKey: taskId)
                    recurrenceTypeMap.removeValue(forKey: taskId)
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("updateTask failed: \($0.message)") }
            )
        }
    }

    func updateAllRepeatedTasks(taskId: String, title: String, description: String, labelId: String,
                                priorityLevelId: String, startDatetime: String, endDatetime: String,
                                location: String?) {
        Task {
            await AppRepository.updateRepeatedTasks(
                taskId: taskId, title: title, description: description.nonBlank,
                labelId: labelId, priorityLevelId: priorityLevelId,
                startDatetime: startDatetime, endDatetime: endDatetime, location: location
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

    private func loadLookupData() async {
        async let labelsResult = AppRepository.getLabels()
        async let priorityResult = AppRepository.getPriorityLevels()
        await labelsResult.onSuccess { labels = $0 }
        await priorityResult.onSuccess { priorityLevels = $0 }
    }
}

// ── Weekly report (shared by family + caregiver) ───────────────────

@MainActor
final class ReportViewModel: ObservableObject {

    @Published var reportState: UiState<WeeklySummaryData> = .idle
    @Published var selectedWeekStart: String = ReportViewModel.thisMonday()

    init() { loadReport() }

    func loadReport() {
        Task {
            reportState = .loading
            let seniorId = TokenManager.getSeniorUserId() ?? TokenManager.getUserId()
            await AppRepository.getWeeklySummary(seniorUserId: seniorId,
                                                weekStart: selectedWeekStart).fold(
                onSuccess: { reportState = .success($0) },
                onFailure: { reportState = .error($0.message.isEmpty ? "Failed to load report" : $0.message) }
            )
        }
    }

    func selectPreviousWeek() { shiftWeek(by: -7) }
    func selectNextWeek() { shiftWeek(by: 7) }

    private func shiftWeek(by days: Int) {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy-MM-dd"
        let current = f.date(from: selectedWeekStart) ?? Date()
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: current) ?? current
        selectedWeekStart = f.string(from: shifted)
        loadReport()
    }

    private static func thisMonday() -> String {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday, matching Calendar.MONDAY on Android
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }
}
