//
//  ShoppingListViewModel.swift
//  Port of shared/ShoppingListViewModel.kt.
//

import Foundation
import Combine

@MainActor
final class ShoppingListViewModel: ObservableObject {

    @Published var shoppingState: UiState<[TaskItem]> = .idle
    @Published var offersMap: [String: TaskAssignmentOffer] = [:]
    @Published var labels: [TaskLabel] = []

    private var groceryLabelId: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadLabels()
        observeShoppingRefresh()
    }

    private func observeShoppingRefresh() {
        NotificationEventBus.shared.shoppingRefreshEvents
            .sink { [weak self] _ in self?.loadItems() }
            .store(in: &cancellables)
    }

    private func loadLabels() {
        Task {
            await AppRepository.getLabels()
                .onSuccess { labelList in
                    labels = labelList
                    groceryLabelId = labelList.first { label in
                        label.label.range(of: "grocer", options: .caseInsensitive) != nil
                            || label.label.range(of: "shop", options: .caseInsensitive) != nil
                    }?.labelId
                    loadItems()
                }
                .onFailure { _ in loadItems() }
        }
    }

    func loadItems() {
        Task {
            shoppingState = .loading
            await AppRepository.getShoppingTasks(groceryLabelId: groceryLabelId).fold(
                onSuccess: { tasks in
                    // Completed items disappear from the list entirely instead of
                    // staying visible with a strikethrough.
                    let activeTasks = tasks.filterNotCompleted()
                    shoppingState = .success(activeTasks)
                    await loadOffersForTasks(activeTasks.map(\.taskId))
                },
                onFailure: { shoppingState = .error($0.message.isEmpty ? "Failed to load list" : $0.message) }
            )
        }
    }

    private func loadOffersForTasks(_ taskIds: [String]) async {
        offersMap = await loadOffersMap(taskIds: taskIds)
    }

    func addItem(name: String, quantity: String, description: String, location: String,
                 dueDate: String?, assignToUserId: String?) {
        Task {
            let fullName = quantity.isNotBlank ? "\(name) (x\(quantity))" : name
            await AppRepository.createShoppingTask(
                itemName: fullName,
                description: description.nonBlank,
                location: location.nonBlank,
                groceryLabelId: groceryLabelId,
                dueDatetime: dueDate.map { "\($0)T00:00:00" }
            ).onSuccess { task in
                if let assignToUserId {
                    _ = await AppRepository.createAssignmentOffer(
                        taskId: task.taskId, toUserId: assignToUserId, message: "Shopping: \(fullName)")
                }
                loadItems()
            }
        }
    }

    func editItem(taskId: String, name: String, quantity: String, description: String,
                  location: String, dueDate: String?, assignToUserId: String? = nil) {
        Task {
            let fullName = quantity.isNotBlank ? "\(name) (x\(quantity))" : name
            let startDt = dueDate.map { "\($0)T00:00:00" }
            let endDt   = dueDate.map { "\($0)T23:59:59" }
            await AppRepository.updateTask(
                taskId: taskId,
                title: fullName,
                description: description.nonBlank,
                startDatetime: startDt,
                endDatetime: endDt,
                location: location.nonBlank
            ).onSuccess { _ in
                if let assignToUserId {
                    await AppRepository.createAssignmentOffer(
                        taskId: taskId, toUserId: assignToUserId, message: "Shopping: \(fullName)"
                    ).onFailure { LogManager.logError("createAssignmentOffer failed: \($0.message)") }
                }
                loadItems()
            }
        }
    }

    func toggleBought(taskId: String) {
        Task {
            await AppRepository.markShoppingItemBought(taskId: taskId).onSuccess { _ in loadItems() }
        }
    }

    func deleteItem(taskId: String) {
        Task {
            LogManager.logInfo("deleteItem called with taskId=\(taskId)")
            // Shopping list items are tasks — use the task delete endpoint
            await AppRepository.deleteTask(taskId: taskId).fold(
                onSuccess: { _ in LogManager.logInfo("deleteItem success"); loadItems() },
                onFailure: { LogManager.logError("deleteItem failed: \($0.message)"); loadItems() }
            )
        }
    }

    func acceptOffer(offerId: String) {
        Task {
            await AppRepository.acceptOffer(offerId: offerId).fold(
                onSuccess: { _ in loadItems() },
                onFailure: { LogManager.logError("acceptOffer failed: \($0.message)") }
            )
        }
    }

    func declineOffer(offerId: String) {
        Task {
            await AppRepository.declineOffer(offerId: offerId).fold(
                onSuccess: { _ in loadItems() },
                onFailure: { LogManager.logError("declineOffer failed: \($0.message)") }
            )
        }
    }
}
