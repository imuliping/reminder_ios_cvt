//
//  CaregiverViewModels.swift
//  Ports of CaregiverHomeViewModel (caregiver/CaregiverHomeScreen.kt),
//  CaregiverAvailableTimeViewModel (caregiver/CaregiverAvaliableTimeScreen.kt)
//  and CaregiverScheduleViewModel (caregiver/CaregiverScheduleScreen.kt).
//

import Foundation
import Combine

// ── Caregiver Home ────────────────────────────────────────────────

@MainActor
final class CaregiverHomeViewModel: ObservableObject {

    @Published var tasksState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    /// Offers waiting for this caregiver's response.
    @Published var offersForMe: [TaskAssignmentOffer] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadUpcomingTasks()
        loadOffersForMe()
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in
                self?.loadUpcomingTasks()
                self?.loadOffersForMe()
            }
            .store(in: &cancellables)
    }

    func loadUpcomingTasks() {
        Task {
            tasksState = .loading
            let fromDt = todayString()
            let toDt   = dayOffsetString(7)
            await AppRepository.getScheduleTasks(fromDt: fromDt, toDt: toDt).fold(
                onSuccess: { tasks in
                    let upcoming = tasks
                        .filterJunk()
                        .filter { !($0.startDatetime.isNullOrEmpty) }
                        .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }
                    tasksState = .success(upcoming)
                    offersMap = await loadOffersMap(taskIds: upcoming.map(\.taskId))
                },
                onFailure: { tasksState = .error($0.message.isEmpty ? "Failed to load tasks" : $0.message) }
            )
        }
    }

    func loadOffersForMe() {
        Task {
            await AppRepository.getMyOffers(status: "PENDING").onSuccess { pending in
                offersForMe = pending.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            }
        }
    }
}

// ── Caregiver Available Time ───────────────────────────────────────

struct TimeSlot: Identifiable {
    let time: String
    let hour: Int
    let isLocked: Bool
    var taskTitle: String? = nil
    var id: Int { hour }
}

struct DayOption: Identifiable, Hashable {
    let label: String
    let date: String
    let display: String
    var id: String { date }
}

@MainActor
final class CaregiverAvailableTimeViewModel: ObservableObject {

    @Published var slotsState: UiState<[TimeSlot]> = .idle
    @Published var availableDays: [DayOption] = []
    @Published var selectedDay: DayOption?

    private var seniorTasks: [TaskItem] = []
    private let dayHours = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    private var cancellables = Set<AnyCancellable>()

    init() {
        buildNext7Days()
        loadSeniorTasks()
        observeScheduleRefresh()
    }

    private func buildNext7Days() {
        let apiFmt = DateFormatter()
        apiFmt.locale = Locale.current
        apiFmt.dateFormat = "yyyy-MM-dd"
        apiFmt.timeZone = userTimeZone()
        let displayFmt = DateFormatter()
        displayFmt.locale = Locale.current
        displayFmt.dateFormat = "EEE, MMM d"
        displayFmt.timeZone = userTimeZone()

        var calendar = Calendar.current
        calendar.timeZone = userTimeZone()
        let days: [DayOption] = (0...6).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            let dayNum = calendar.component(.day, from: date)
            let suffix: String
            switch true {
            case dayNum % 10 == 1 && dayNum != 11: suffix = "st"
            case dayNum % 10 == 2 && dayNum != 12: suffix = "nd"
            case dayNum % 10 == 3 && dayNum != 13: suffix = "rd"
            default:                               suffix = "th"
            }
            return DayOption(label: "\(dayNum)\(suffix)",
                             date: apiFmt.string(from: date),
                             display: displayFmt.string(from: date))
        }
        availableDays = days
        selectedDay = days.first
    }

    func selectDay(_ day: DayOption) {
        selectedDay = day
        buildSlotsForSelectedDay()
    }

    func loadSlots() { loadSeniorTasks() }

    private func loadSeniorTasks() {
        Task {
            slotsState = .loading

            // Use the seniorUserId stored at login.
            guard let seniorId = TokenManager.getSeniorUserId() else {
                slotsState = .error("No linked senior found")
                return
            }

            let fromDt = availableDays.first?.date ?? ""
            let toDt   = availableDays.last?.date ?? fromDt

            // Pass userId as well so the caregiver's token can see the senior's
            // tasks across family account boundaries.
            await AppRepository.getScheduleTasks(subjectUserId: seniorId, userId: seniorId,
                                                fromDt: fromDt, toDt: toDt).fold(
                onSuccess: { tasks in
                    // Only show tasks the senior created for themselves
                    seniorTasks = tasks
                        .filter { !($0.startDatetime.isNullOrEmpty) }
                        .filter { $0.createdByUserId == seniorId && $0.subjectUserId == seniorId }
                    buildSlotsForSelectedDay()
                },
                onFailure: {
                    slotsState = .error($0.message.isEmpty ? "Failed to load senior's schedule" : $0.message)
                }
            )
        }
    }

    private func buildSlotsForSelectedDay() {
        guard let day = selectedDay else { return }
        let tasksForDay = seniorTasks.filter { $0.startDatetime?.hasPrefix(day.date) == true }

        let slots = dayHours.map { hour -> TimeSlot in
            let blockingTask = tasksForDay.first { isHourWithinTask(hour, $0) }
            return TimeSlot(time: formatHourLabel(hour),
                            hour: hour,
                            isLocked: blockingTask != nil,
                            taskTitle: blockingTask?.displayName)
        }
        slotsState = .success(slots)
    }

    private func isHourWithinTask(_ hour: Int, _ task: TaskItem) -> Bool {
        guard let start = task.startDatetime else { return false }
        let end = task.endDatetime ?? start
        func minutes(_ datetime: String) -> Int? {
            guard let timePart = datetime.split(separator: "T").dropFirst().first else { return nil }
            let comps = timePart.split(separator: ":")
            guard let h = Int(comps.first ?? "") else { return nil }
            let m = comps.count > 1 ? (Int(comps[1]) ?? 0) : 0
            return h * 60 + m
        }
        guard let taskStart = minutes(start) else { return false }
        let taskEnd = (end == start) ? taskStart + 60 : (minutes(end) ?? taskStart + 60)
        let slotStart = hour * 60
        let slotEnd = slotStart + 60
        return taskStart < slotEnd && taskEnd > slotStart
    }

    private func formatHourLabel(_ hour: Int) -> String {
        let period = hour < 12 ? "a.m." : "p.m."
        let displayHour: Int = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadSeniorTasks() }
            .store(in: &cancellables)
    }
}

// ── Caregiver Schedule ────────────────────────────────────────────

@MainActor
final class CaregiverScheduleViewModel: ObservableObject {

    @Published var tasksState: UiState<[TaskItem]> = .idle
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
        tasksState = .loading
        let myUserId = TokenManager.getUserId() ?? ""
        let seniorId = TokenManager.getSeniorUserId()

        let seniorTasks = (showAllSchedule || showAllTodo)
            ? await AppRepository.getScheduleTasks(subjectUserId: seniorId).getOrElse([])
            : await AppRepository.getUpcomingScheduleTasks(subjectUserId: seniorId).getOrElse([])

        let assignedToMe = await AppRepository.getScheduleTasks(assignedTo: myUserId).getOrElse([])

        var seen = Set<String>()
        let merged = (seniorTasks + assignedToMe)
            .filter { seen.insert($0.taskId).inserted }
            .filterJunk()
            .filterNotCompleted()

        tasksState = .success(merged)
        offersMap = await loadOffersMap(taskIds: merged.map(\.taskId))
    }

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadTasks() }
            .store(in: &cancellables)
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

    /// Caregivers cannot assign tasks to anyone, so there is no assignTo parameter.
    func createTask(title: String, description: String, labelId: String, priorityLevelId: String,
                    startDatetime: String, endDatetime: String, location: String?,
                    repeatTypeName: String? = nil) {
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
                    endDatetime: endDatetime, location: location,
                    subjectUserId: TokenManager.getSeniorUserId())
            }

            await taskResult.fold(
                onSuccess: { task in
                    if let myUserId = TokenManager.getUserId() {
                        await AppRepository.assignTaskToUser(taskId: task.taskId, userId: myUserId)
                            .onFailure { LogManager.logError("caregiver self-assign failed: \($0.message)") }
                    }
                    await loadTasksAsync()
                },
                onFailure: { LogManager.logError("caregiver createTask failed: \($0.message)") }
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
