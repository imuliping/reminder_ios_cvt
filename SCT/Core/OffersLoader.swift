//
//  OffersLoader.swift
//  The `loadOffersForTasks` fan-out that every schedule-style ViewModel repeated
//  on Android (async { … }.awaitAll() + maxByOrNull { createdAt }).
//

import Foundation

/// Fetches the newest offer per task id, in parallel.
func loadOffersMap(taskIds: [String]) async -> [String: TaskAssignmentOffer] {
    guard !taskIds.isEmpty else { return [:] }
    return await withTaskGroup(of: (String, [TaskAssignmentOffer]).self) { group in
        for taskId in taskIds {
            group.addTask {
                (taskId, await AppRepository.getOffersForTask(taskId: taskId).getOrElse([]))
            }
        }
        var map: [String: TaskAssignmentOffer] = [:]
        for await (taskId, offers) in group {
            if let latest = offers.max(by: { ($0.createdAt ?? "") < ($1.createdAt ?? "") }) {
                map[taskId] = latest
            }
        }
        return map
    }
}
