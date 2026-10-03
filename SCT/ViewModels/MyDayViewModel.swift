//
//  MyDayViewModel.swift
//  Port of the MyDayViewModel in senior/MyDayScreen.kt.
//

import Foundation
import Combine

@MainActor
final class MyDayViewModel: ObservableObject {

    @Published var tasksState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    @Published var labels: [TaskLabel] = []
    @Published var priorityLevels: [PriorityLevel] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadTodayTasks()
        loadLookupData()
        observeScheduleRefresh()
    }

    func loadTodayTasks() {
        Task { await loadTodayTasksAsync() }
    }

    private func loadTodayTasksAsync() async {
        tasksState = .loading
        // AppRepository.getTodayTasks() resolves seniorId as:
        //   isSenior() ? getUserId() : getSeniorUserId()
        await AppRepository.getTodayTasks().fold(
            onSuccess: { tasks in
                let sorted = tasks.filterJunk().sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }
                tasksState = .success(sorted)
                offersMap = await loadOffersMap(taskIds: sorted.map(\.taskId))
            },
            onFailure: { tasksState = .error($0.message.isEmpty ? "Failed to load today's tasks" : $0.message) }
        )
    }

    private func observeScheduleRefresh() {
        NotificationEventBus.shared.scheduleRefreshEvents
            .sink { [weak self] _ in self?.loadTodayTasks() }
            .store(in: &cancellables)
    }

    func createQuickTask(title: String, description: String, hour: String, minute: String,
                         assignToUserId: String? = nil, repeatTypeName: String? = nil,
                         labelId: String, priorityId: String,
                         selectedWeekdays: [String]? = nil) {
        Task {
            guard let (startDt, endDt) = quickTaskWindow(hour: hour, minute: minute) else {
                tasksState = .error("Enter a valid reminder time.")
                return
            }
            let result = if let repeatTypeName {
                await AppRepository.createTaskWithRecurrence(
                    title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityId,
                    startDatetime: startDt, endDatetime: endDt, location: nil,
                    subjectUserId: TokenManager.getUserId(),
                    repeatTypeName: repeatTypeName,
                    selectedWeekdays: selectedWeekdays)
            } else {
                await AppRepository.createTask(
                    title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityId,
                    startDatetime: startDt, endDatetime: endDt)
            }
            await result.onSuccess { task in
                if let assignToUserId {
                    _ = await AppRepository.createAssignmentOffer(
                        taskId: task.taskId, toUserId: assignToUserId,
                        message: "You've been assigned: \(title)")
                }
                await loadTodayTasksAsync()
            }
        }
    }

    func updateQuickTask(taskId: String, title: String, description: String,
                         hour: String, minute: String, assignToUserId: String? = nil,
                         repeatTypeName: String? = nil, originalDate: String? = nil,
                         labelId: String, priorityId: String,
                         selectedWeekdays: [String]? = nil) {
        Task {
            guard let (startDt, endDt) = quickTaskWindow(
                hour: hour, minute: minute, date: originalDate
            ) else {
                tasksState = .error("Enter a valid reminder time.")
                return
            }
            let result = if let repeatTypeName {
                await AppRepository.updateTaskWithRecurrence(
                    taskId: taskId, title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityId,
                    startDatetime: startDt, endDatetime: endDt, location: nil,
                    repeatTypeName: repeatTypeName,
                    selectedWeekdays: selectedWeekdays)
            } else {
                await AppRepository.updateTask(
                    taskId: taskId, title: title, description: description.nonBlank,
                    labelId: labelId, priorityLevelId: priorityId,
                    startDatetime: startDt, endDatetime: endDt)
            }
            await result.onSuccess { _ in
                if let assignToUserId {
                    _ = await AppRepository.createAssignmentOffer(
                        taskId: taskId, toUserId: assignToUserId,
                        message: "You've been assigned: \(title)")
                }
                await loadTodayTasksAsync()
            }
        }
    }

    func completeTask(taskId: String) {
        Task { await AppRepository.completeTask(taskId: taskId).onSuccess { _ in await loadTodayTasksAsync() } }
    }

    func skipTask(taskId: String) {
        Task { await AppRepository.skipTask(taskId: taskId).onSuccess { _ in await loadTodayTasksAsync() } }
    }

    func acceptOffer(offerId: String) {
        Task { await AppRepository.acceptOffer(offerId: offerId).onSuccess { _ in await loadTodayTasksAsync() } }
    }

    func declineOffer(offerId: String) {
        Task { await AppRepository.declineOffer(offerId: offerId).onSuccess { _ in await loadTodayTasksAsync() } }
    }

    private func loadLookupData() {
        Task {
            await AppRepository.getLabels().onSuccess { labels = $0 }
            await AppRepository.getPriorityLevels().onSuccess { priorityLevels = $0 }
        }
    }
}
