//
//  TaskIcon.swift
//  Port of getTaskIcon() in shared/SharedComponents.kt. Material icons are
//  mapped to their nearest SF Symbol equivalents.
//

import SwiftUI

struct TaskIconStyle {
    let systemName: String
    let tint: Color
}

private let iconTint = Color(hex: 0x757575)

func getTaskIcon(_ title: String, _ description: String) -> TaskIconStyle {
    let text = (title + " " + description).lowercased()

    // Icons.Default.Medication
    if text.containsAny("medicine", "medication", "pill", "tablet", "insulin",
                        "amlodipine", "metformin", "drug", "dose", "prescription", "pharmacy",
                        "vitamin", "supplement", "inhaler") {
        return TaskIconStyle(systemName: "pills.fill", tint: iconTint)
    }
    // Icons.Default.DirectionsCar
    if text.containsAny("visit", "drive", "car", "travel", "trip", "pick up",
                        "drop off", "transport", "uber", "taxi", "bus", "ride") {
        return TaskIconStyle(systemName: "car.fill", tint: iconTint)
    }
    // Icons.Default.FitnessCenter
    if text.containsAny("exercise", "gym", "workout", "fitness", "walk", "run",
                        "jog", "yoga", "stretch", "sport", "swim", "bike", "daily exercise") {
        return TaskIconStyle(systemName: "figure.walk", tint: iconTint)
    }
    // Icons.Default.MonitorHeart
    if text.containsAny("checkup", "health", "blood pressure", "measurement",
                        "doctor", "clinic", "hospital", "appointment", "nurse", "dentist",
                        "therapy", "treatment", "monitor") {
        return TaskIconStyle(systemName: "waveform.path.ecg", tint: iconTint)
    }
    // Icons.Default.ShoppingCart
    if text.containsAny("shop", "grocery", "groceries", "buy", "purchase",
                        "market", "store", "supermarket") {
        return TaskIconStyle(systemName: "cart.fill", tint: iconTint)
    }
    // Icons.Default.Restaurant
    if text.containsAny("breakfast", "lunch", "dinner", "meal", "eat", "food",
                        "cook", "bake", "restaurant", "cafe") {
        return TaskIconStyle(systemName: "fork.knife", tint: iconTint)
    }
    // Icons.Default.WbSunny
    if text.containsAny("wake", "morning", "get up", "rise", "alarm") {
        return TaskIconStyle(systemName: "sun.max.fill", tint: iconTint)
    }
    // Icons.Default.Phone
    if text.containsAny("call", "phone", "chat", "talk", "social", "friend",
                        "family", "bingo", "church", "community") {
        return TaskIconStyle(systemName: "phone.fill", tint: iconTint)
    }
    // Icons.Default.CleaningServices
    if text.containsAny("clean", "laundry", "wash", "chore", "house",
                        "vacuum", "mop", "dishes", "trash") {
        return TaskIconStyle(systemName: "sparkles", tint: iconTint)
    }
    // Icons.Default.LocalFlorist
    if text.containsAny("flower", "garden", "plant", "water", "tulip",
                        "rose", "grass", "lawn", "weed", "trim", "prune") {
        return TaskIconStyle(systemName: "leaf.fill", tint: iconTint)
    }
    // Icons.AutoMirrored.Filled.Assignment
    return TaskIconStyle(systemName: "list.clipboard.fill", tint: iconTint)
}

/// Port of `List<Task>.filterJunk()` in senior/MyDayScreen.kt.
extension Array where Element == TaskItem {
    func filterJunk() -> [TaskItem] {
        filter { task in
            let name = (task.title?.trimmingCharacters(in: .whitespaces)
                        ?? task.shortDescription?.trimmingCharacters(in: .whitespaces)
                        ?? task.name?.trimmingCharacters(in: .whitespaces)
                        ?? task.description?.trimmingCharacters(in: .whitespaces)
                        ?? "")
            let lower = name.lowercased()
            return !name.isEmpty && lower != "string" && lower != "untitled" && name.count > 1
        }
    }

    /// The "not finished" filter repeated across every schedule screen.
    func filterNotCompleted() -> [TaskItem] {
        filter { task in
            let done = ["completed", "done"]
            let s = task.status?.lowercased()
            let sid = task.taskStatusId?.lowercased()
            return !(s.map { done.contains($0) } ?? false)
                && !(sid.map { done.contains($0) } ?? false)
        }
    }
}

/// Port of StatusIndicator in senior/MyDayScreen.kt.
enum StatusIndicator {
    case completed, skipped, started, pending, overdue
}
