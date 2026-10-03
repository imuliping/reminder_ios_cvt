//
//  ShoppingListView.swift
//  Port of shared/ShoppingListScreen.kt.
//

import SwiftUI

struct ShoppingListView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    var canAssign: Bool = true
    @StateObject private var vm = ShoppingListViewModel()

    @State private var showAddDialog = false
    @State private var showEditDialog = false
    @State private var showDeleteConfirm = false
    @State private var editingTask: TaskItem?

    private var tasks: [TaskItem] { vm.shoppingState.data ?? [] }

    /// Group by due date: tasks with a date sorted ascending, then no-date at the bottom.
    private var grouped: [(String?, [TaskItem])] {
        let withDate = tasks.filter { !($0.startDatetime.isNullOrEmpty) }
            .sorted { ($0.startDatetime ?? "") < ($1.startDatetime ?? "") }
        var buckets: [String: [TaskItem]] = [:]
        var order: [String] = []
        for task in withDate {
            let key = (task.startDatetime ?? "").take(10)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(task)
        }
        var result: [(String?, [TaskItem])] = order.map { ($0, buckets[$0] ?? []) }
        let withoutDate = tasks.filter { $0.startDatetime.isNullOrEmpty }
        if !withoutDate.isEmpty { result.append((nil, withoutDate)) }
        return result
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                .padding(.leading, 16)

                Spacer().frame(height: 4)

                content
                    .padding(.horizontal, 16)

                MessageEldaBar { onNavigate("aichat") }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
            .background(Color.white)

            if canAssign {
                Button { showAddDialog = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(TextDark)
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 96)
                .padding(.trailing, 24)
            }
        }
        // Screen-level delete confirmation — fires vm.deleteItem directly
        .alert("Delete Item?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let taskId = editingTask?.taskId else { return }
                showEditDialog = false
                editingTask = nil
                vm.deleteItem(taskId: taskId)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item will be permanently deleted.")
        }
        .sheet(isPresented: $showAddDialog) {
            ShoppingItemDialog(
                title: "Add Item",
                canAssign: canAssign,
                onDismiss: { showAddDialog = false },
                onSave: { name, quantity, detail, location, dueDate, assignTo in
                    vm.addItem(name: name, quantity: quantity, description: detail,
                               location: location, dueDate: dueDate, assignToUserId: assignTo)
                    showAddDialog = false
                }
            )
        }
        .sheet(isPresented: $showEditDialog) {
            if let taskSnapshot = editingTask {
                ShoppingItemDialog(
                    title: "Edit Item",
                    existingName: taskSnapshot.displayName,
                    existingDetail: taskSnapshot.description ?? "",
                    existingLocation: taskSnapshot.location ?? "",
                    existingDueDate: taskSnapshot.startDatetime?.take(10) ?? "",
                    canAssign: canAssign,
                    showDelete: true,
                    onDismiss: { showEditDialog = false; editingTask = nil },
                    onSave: { name, quantity, detail, location, dueDate, assignTo in
                        vm.editItem(taskId: taskSnapshot.taskId, name: name, quantity: quantity,
                                    description: detail, location: location,
                                    dueDate: dueDate, assignToUserId: assignTo)
                        showEditDialog = false
                        editingTask = nil
                    },
                    onDelete: { showDeleteConfirm = true }   // triggers the screen-level confirm
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = vm.shoppingState.errorMessage {
            Spacer()
            ErrorRetry(message: message) { vm.loadItems() }
            Spacer()
        } else if tasks.isEmpty && !vm.shoppingState.isLoading {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "cart")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(.lightGray))
                Spacer().frame(height: 8)
                Text("Your shopping list is empty.").font(appFont(15)).foregroundStyle(TextGray)
                Text("Tap + to add an item.").font(appFont(14)).foregroundStyle(TextGray)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                        let dateKey = group.0
                        // Date group header
                        VStack(spacing: 0) {
                            Text(dateKey == nil ? "No date" : "By \(formatShoppingDate(dateKey!))")
                                .font(appFont(13, .bold))
                                .foregroundStyle(dateKey == nil ? TextGray : TextDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                            Divider().background(Color(hex: 0xDDDDDD))
                        }

                        ForEach(group.1) { task in
                            let offer = vm.offersMap[task.taskId]
                            let isBought = ["completed", "done"].contains(task.status?.lowercased() ?? "")
                                || ["completed", "done"].contains(task.taskStatusId?.lowercased() ?? "")
                            ShoppingTaskRow(
                                task: task,
                                offer: offer,
                                isBought: isBought,
                                isAssignedToMe: offer?.toUserId == TokenManager.getUserId(),
                                onChecked: { vm.toggleBought(taskId: task.taskId) },
                                onTap: {
                                    if canAssign { editingTask = task; showEditDialog = true }
                                },
                                onAccept: { if let id = offer?.offerId { vm.acceptOffer(offerId: id) } },
                                onDecline: { if let id = offer?.offerId { vm.declineOffer(offerId: id) } }
                            )
                        }
                    }
                    Spacer().frame(height: 80)
                }
            }
            .refreshable { vm.loadItems() }
        }
    }
}

// ── Task Row ──────────────────────────────────────────────────────

struct ShoppingTaskRow: View {

    let task: TaskItem
    let offer: TaskAssignmentOffer?
    let isBought: Bool
    let isAssignedToMe: Bool
    let onChecked: () -> Void
    let onTap: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        let isPending = offer?.status?.uppercased() == "PENDING"

        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onChecked) {
                    Image(systemName: isBought ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(TextDark)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.displayName)
                        .font(appFont(16, .bold))
                        .strikethrough(isBought)
                        .foregroundStyle(isBought ? TextGray : TextDark)
                    if let description = task.description, description.isNotEmpty {
                        Text(description)
                            .font(appFont(13))
                            .foregroundStyle(TextGray)
                            .strikethrough(isBought)
                    }
                    if let location = task.location, location.isNotEmpty {
                        Text("📍 \(location)").font(appFont(12)).foregroundStyle(TextGray)
                    }
                    if let offer {
                        Spacer().frame(height: 4)
                        OfferStatusText(offer: offer, isAssignedToMe: isAssignedToMe)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isAssignedToMe && isPending {
                OfferActionRow(onAccept: onAccept, onDecline: onDecline)
                Spacer().frame(height: 8)
            }

            Divider().background(Color(hex: 0xEEEEEE))
        }
    }
}

// ── Dialog ────────────────────────────────────────────────────────

struct ShoppingItemDialog: View {

    let title: String
    var existingName: String = ""
    var existingQuantity: String = ""
    var existingDetail: String = ""
    var existingLocation: String = ""
    var existingDueDate: String = ""        // yyyy-MM-dd or ""
    var canAssign: Bool = true
    var showDelete: Bool = false
    let onDismiss: () -> Void
    let onSave: (String, String, String, String, String?, String?) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var name = ""
    @State private var quantity = ""
    @State private var detail = ""
    @State private var location = ""
    @State private var errorMessage = ""
    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var candidates: [TaskAssignmentCandidate] = []
    @State private var selectedCandidate: TaskAssignmentCandidate?
    @State private var didInit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(appFont(20, .bold))
                    Spacer()
                    if showDelete, let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 17))
                                .foregroundStyle(DangerRed)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 6)

                labelledField("Item name *") {
                    TextField("", text: $name).font(appFont(15))
                        .textInputAutocapitalization(.sentences)
                }
                labelledField("Quantity") {
                    TextField("", text: $quantity).font(appFont(15)).keyboardType(.numberPad)
                }
                labelledField("Description") {
                    TextField("", text: $detail, axis: .vertical)
                        .font(appFont(15))
                        .lineLimit(2...3)
                        .textInputAutocapitalization(.sentences)
                }
                labelledField("Location (store, aisle…)") {
                    TextField("", text: $location).font(appFont(15))
                        .textInputAutocapitalization(.sentences)
                }

                Spacer().frame(height: 2)

                Text("Buy by (optional):").font(appFont(14, .bold)).foregroundStyle(TextDark)
                HStack(spacing: 0) {
                    SDateBox(value: $dateYear, placeholder: "YYYY", width: 70, maxLength: 4)
                    Text("-").font(appFont(15, .bold)).foregroundStyle(TextDark).padding(.horizontal, 3)
                    SDateBox(value: $dateMonth, placeholder: "MM", width: 46, maxLength: 2)
                    Text("-").font(appFont(15, .bold)).foregroundStyle(TextDark).padding(.horizontal, 3)
                    SDateBox(value: $dateDay, placeholder: "DD", width: 46, maxLength: 2)
                    if dateYear.isNotBlank || dateMonth.isNotBlank || dateDay.isNotBlank {
                        Button {
                            dateYear = ""; dateMonth = ""; dateDay = ""
                        } label: {
                            Text("Clear").font(appFont(12)).foregroundStyle(TextGray)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                }

                if canAssign && !candidates.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assign to").font(appFont(14, .bold))
                        PillMenu(items: candidates,
                                 title: { $0.displayName ?? "Unknown" },
                                 subtitle: { $0.role?.capitalizedFirst },
                                 noneLabel: "No one",
                                 onSelect: { selectedCandidate = $0 }) {
                            PillMenuLabel(text: selectedCandidate?.displayName ?? "No one")
                        }
                    }
                }

                if errorMessage.isNotBlank {
                    Text(errorMessage).font(appFont(13)).foregroundStyle(.red)
                }

                Spacer().frame(height: 6)

                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(appFont(15))
                            .foregroundStyle(DangerRed)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .roundedBorder(DangerRed, 1, radius: 50)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if name.isBlank { errorMessage = "Item name is required."; return }
                        // Build the due date string only when all parts are filled
                        let dueDate: String? = (dateYear.isNotBlank && dateMonth.isNotBlank && dateDay.isNotBlank)
                            ? "\(dateYear.padStart(4, "0"))-\(dateMonth.padStart(2, "0"))-\(dateDay.padStart(2, "0"))"
                            : nil
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               quantity.trimmingCharacters(in: .whitespaces),
                               detail.trimmingCharacters(in: .whitespaces),
                               location.trimmingCharacters(in: .whitespaces),
                               dueDate,
                               selectedCandidate?.userId)
                    } label: {
                        Text("Save")
                            .font(appFont(15, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppGreen)
                            .rounded(50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .task {
            guard !didInit else { return }
            didInit = true
            name = existingName
            quantity = existingQuantity
            detail = existingDetail
            location = existingLocation
            let parts = existingDueDate.split(separator: "-").map(String.init)
            if parts.count == 3 {
                dateYear = parts[0]; dateMonth = parts[1]; dateDay = parts[2]
            }
            if canAssign {
                await AppRepository.getAssignmentCandidates().onSuccess { list in
                    let myId = TokenManager.getUserId()
                    candidates = list.filter {
                        $0.userId != myId && !($0.displayName.isNullOrBlank)
                            && $0.displayName?.lowercased() != "string"
                            && $0.role?.lowercased() != "senior"
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labelledField<Content: View>(_ label: String,
                                             @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(appFont(12)).foregroundStyle(TextGray)
            content()
                .padding(12)
                .roundedBorder(BorderGray, 1, radius: 12)
        }
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
