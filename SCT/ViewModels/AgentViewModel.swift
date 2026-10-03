//
//  AgentViewModel.swift
//  Port of shared/AgentViewModel.kt — Elda, the AI assistant.
//

import Foundation

enum AgentResponse {
    case reply(text: String, cards: [ConversationCard] = [])
    case confirmationNeeded(text: String, questions: [String], pendingIntentId: String, pendingMessage: String)
    case clarificationNeeded(text: String, pendingIntentId: String)
}

@MainActor
final class AgentViewModel: ObservableObject {

    @Published var responseState: UiState<AgentResponse> = .idle
    @Published var dialogs: [AgentDialogSummary] = []
    @Published var loadingHistory = false
    @Published var historyError: String?
    @Published var conversationTitle = "New conversation"

    private var currentDialogId: String?
    private var sourceScreen: String = "home"
    private var contextInjected = false
    private var pendingClarificationIntentId: String?

    /// Tracks which user owns the in-memory dialog so we reset on user switch.
    private var dialogOwnerUserId: String?

    /// Stores recurrence info from the parsed action so we can apply it after confirm.
    private var pendingRecurrenceTypeName: String?

    func setSourceScreen(_ screen: String) {
        let currentUserId = TokenManager.getUserId()
        if dialogOwnerUserId != nil && dialogOwnerUserId != currentUserId {
            LogManager.logInfo("AgentViewModel: user changed (\(dialogOwnerUserId ?? "nil") -> \(currentUserId ?? "nil")), resetting dialog")
            resetDialog()
        }
        sourceScreen = screen
        contextInjected = false
    }

    func initialize(_ screen: String, onLoaded: @escaping ([ChatMessage]) -> Void) {
        setSourceScreen(screen)
        if currentDialogId == nil, let saved = TokenManager.getDialogId(), saved.isNotBlank {
            currentDialogId = saved
            dialogOwnerUserId = TokenManager.getUserId()
            loadHistory(onLoaded: onLoaded)
        }
        refreshHistory()
    }

    func refreshHistory() {
        Task {
            loadingHistory = true
            historyError = nil
            await AppRepository.listAgentDialogs().fold(
                onSuccess: { rows in
                    dialogs = rows.sorted {
                        ($0.updatedAt ?? $0.createdAt ?? "") > ($1.updatedAt ?? $1.createdAt ?? "")
                    }
                    loadingHistory = false
                },
                onFailure: { error in
                    historyError = error.message
                    loadingHistory = false
                }
            )
        }
    }

    func newConversation() {
        resetDialog()
        conversationTitle = "New conversation"
    }

    func openConversation(_ dialog: AgentDialogSummary, onLoaded: @escaping ([ChatMessage]) -> Void) {
        currentDialogId = dialog.dialogId
        dialogOwnerUserId = TokenManager.getUserId()
        conversationTitle = dialog.title?.isBlank == false ? dialog.title! : "Conversation"
        TokenManager.saveDialogId(dialog.dialogId)
        loadHistory(onLoaded: onLoaded)
    }

    private func sourceScreenLabel() -> String {
        switch sourceScreen {
        case "schedule":           return "Schedule screen (senior's tasks and appointments)"
        case "home":               return "Home screen"
        case "myday":              return "My Day screen (today's tasks)"
        case "notifications":      return "Notifications screen"
        case "shopping":           return "Shopping list screen"
        case "family_home":        return "Family home screen"
        case "family_schedule":    return "Family schedule screen (senior's tasks and appointments)"
        case "family_shopping":    return "Family shopping list screen"
        case "supervise":          return "Supervise screen (family member viewing senior's schedule)"
        case "caregiver_home":     return "Caregiver home screen"
        case "caregiver_schedule": return "Caregiver schedule screen (senior's tasks and appointments)"
        case "caregiver_shopping": return "Caregiver shopping list screen"
        default:                   return sourceScreen
        }
    }

    private func buildContextHeader() -> String {
        let label    = sourceScreenLabel()
        let userId   = TokenManager.getUserId() ?? ""
        let role     = TokenManager.getRoleId()?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        let seniorId = TokenManager.getSeniorUserId() ?? ""

        var s = "[Context: The user opened this chat from the \(label)."
        switch role {
        case "family member":
            s += " The current user is a family member (userId=\(userId))."
            s += " When creating tasks or reminders, ALWAYS assign them to the"
            s += " current family member (subjectUserId=\(userId))."
            s += " Do NOT ask which senior the task is for, and do NOT create"
            s += " tasks for the senior unless the user explicitly says so."
        case "senior":
            s += " The current user is the senior (userId=\(userId))."
            s += " Create all tasks and reminders for this user (subjectUserId=\(userId))."
        case "caregiver", "professional caregiver":
            s += " The current user is a caregiver (userId=\(userId))."
            if seniorId.isNotBlank {
                s += " Tasks and reminders should be created for the assigned senior"
                s += " (subjectUserId=\(seniorId)) unless the user asks for something personal."
            }
        default:
            if userId.isNotBlank { s += " Current userId=\(userId)." }
        }
        s += " Use this to provide relevant answers.]"
        return s
    }

    private func withContext(_ message: String) -> String {
        if contextInjected { return message }
        contextInjected = true
        return "\(buildContextHeader())\n\n\(message)"
    }

    private func injectContextIfNeeded() async {
        if contextInjected { return }
        guard let dialogId = currentDialogId else { return }
        contextInjected = true
        _ = await AppRepository.sendDialogMessage(dialogId: dialogId, role: "user",
                                                 content: buildContextHeader())
    }

    func sendMessage(_ message: String, execute: Bool = true) {
        if let clarificationId = pendingClarificationIntentId {
            pendingClarificationIntentId = nil
            Task {
                responseState = .loading
                await AppRepository.confirmIntent(pendingIntentId: clarificationId).fold(
                    onSuccess: { await handleResponse($0, fallbackMessage: message) },
                    onFailure: {
                        LogManager.logError("confirmIntent for clarification failed: \($0.message), falling back to sendMessage")
                        await sendMessageDirect(message, execute: execute)
                    }
                )
            }
            return
        }
        Task { await sendMessageDirect(message, execute: execute) }
    }

    private func sendMessageDirect(_ message: String, execute: Bool = true) async {
        responseState = .loading
        guard await ensureDialog() != nil else { return }
        let messageWithContext = withContext(message)
        if execute, let dialogId = currentDialogId {
            _ = await AppRepository.sendDialogMessage(dialogId: dialogId, role: "user",
                                                     content: messageWithContext)
        }
        await AppRepository.sendTextAction(text: messageWithContext, dialogId: currentDialogId,
                                          execute: execute).fold(
            onSuccess: { await handleResponse($0, fallbackMessage: messageWithContext) },
            onFailure: { responseState = .error($0.message.isEmpty ? "Elda is unavailable" : $0.message) }
        )
    }

    func confirmAction(pendingIntentId: String, fallbackMessage: String) {
        pendingClarificationIntentId = nil
        Task {
            responseState = .loading
            if pendingIntentId.isNotBlank {
                await AppRepository.confirmIntent(pendingIntentId: pendingIntentId).fold(
                    onSuccess: { await handleResponse($0, fallbackMessage: fallbackMessage) },
                    onFailure: {
                        LogManager.logError("confirmIntent failed: \($0.message), falling back to resend")
                        await sendMessageDirect(fallbackMessage, execute: true)
                    }
                )
            } else {
                await sendMessageDirect(fallbackMessage, execute: true)
            }
        }
    }

    func cancelAction() {
        pendingClarificationIntentId = nil
        responseState = .success(.reply(text: "OK, I've cancelled that."))
    }

    func sendVoiceMessage(file: URL) {
        if let clarificationId = pendingClarificationIntentId {
            pendingClarificationIntentId = nil
            Task {
                responseState = .loading
                guard await ensureDialog() != nil else { return }
                await AppRepository.sendVoiceAction(file: file, dialogId: currentDialogId).fold(
                    onSuccess: { transcribeResponse in
                        let transcript = transcribeResponse.transcript?.lowercased() ?? ""
                        let isNo = transcript.contains("no") || transcript.contains("cancel")
                            || transcript.contains("stop") || transcript.contains("don't")
                            || transcript.contains("nope")
                        if isNo {
                            cancelAction()
                        } else {
                            await AppRepository.confirmIntent(pendingIntentId: clarificationId).fold(
                                onSuccess: { await handleResponse($0, fallbackMessage: transcript) },
                                onFailure: { responseState = .error($0.message.isEmpty ? "Confirmation failed" : $0.message) }
                            )
                        }
                    },
                    onFailure: { responseState = .error($0.message.isEmpty ? "Voice not understood" : $0.message) }
                )
            }
            return
        }
        Task { await sendVoiceMessageDirect(file: file) }
    }

    private func sendVoiceMessageDirect(file: URL) async {
        responseState = .loading
        guard await ensureDialog() != nil else { return }
        await injectContextIfNeeded()
        await AppRepository.sendVoiceAction(file: file, dialogId: currentDialogId).fold(
            onSuccess: { await handleResponse($0, fallbackMessage: $0.transcript ?? "") },
            onFailure: { responseState = .error($0.message.isEmpty ? "Voice not understood" : $0.message) }
        )
    }

    private func handleResponse(_ response: TextActionResponse, fallbackMessage: String) async {
        let replyText = response.assistantReply ?? response.transcript ?? "Done!"

        let action = response.executedAction?.lowercased() ?? ""
        let resultKeys = response.result?.keys.joined(separator: ",").lowercased() ?? ""
        let hasTaskResult = response.result?["taskId"] != nil
            || response.result?["task_id"] != nil
            || resultKeys.contains("taskid")

        let bus = NotificationEventBus.shared
        if hasTaskResult || action.contains("task") || action.contains("schedule")
            || action.contains("shopping") || action.contains("assign") {
            bus.triggerScheduleRefresh()
            bus.triggerShoppingRefresh()
            LogManager.logInfo("Elda action=\(action) hasTaskResult=\(hasTaskResult) — triggered refresh")
        }
        if action.contains("notification") || action.contains("ack")
            || action.contains("dismiss") || action.contains("snooze") {
            bus.triggerNotificationRefresh()
        }

        if response.needsConfirmation == true {
            let questions = response.questions ?? []
            let intentId = response.pendingIntentId ?? ""

            let isClarification = !questions.isEmpty && !questions.contains { q in
                let lower = q.lowercased()
                return lower.hasPrefix("would you") || lower.hasPrefix("shall i")
                    || lower.hasPrefix("do you want") || lower.hasPrefix("should i")
                    || lower.contains("go ahead") || lower.contains("proceed")
            }

            if isClarification {
                pendingClarificationIntentId = intentId
                responseState = .success(.clarificationNeeded(text: replyText, pendingIntentId: intentId))
            } else {
                let replyLower = (replyText + " " + questions.joined(separator: " ")).lowercased()
                let detectedRecurrence: String? = {
                    if replyLower.contains("weekly") || replyLower.contains("week")   { return "weekly" }
                    if replyLower.contains("daily")  || replyLower.contains("day")    { return "daily" }
                    if replyLower.contains("monthly") || replyLower.contains("month") { return "monthly" }
                    return nil
                }()

                if let detectedRecurrence {
                    pendingRecurrenceTypeName = await AppRepository.getRecurrenceTypes().getOrNull?
                        .first { $0.recurrenceType.lowercased() == detectedRecurrence }?
                        .recurrenceType
                } else {
                    pendingRecurrenceTypeName = nil
                }

                responseState = .success(.confirmationNeeded(
                    text: replyText, questions: questions,
                    pendingIntentId: intentId, pendingMessage: fallbackMessage))
            }
        } else {
            pendingClarificationIntentId = nil

            let repeatTypeName = pendingRecurrenceTypeName
            pendingRecurrenceTypeName = nil

            if let repeatTypeName {
                let result = response.result
                let startDt = result?["startDatetime"]?.stringValue ?? result?["start_datetime"]?.stringValue
                if let startDt {
                    let title = result?["title"]?.stringValue ?? "Recurring Task"
                    let desc = result?["description"]?.stringValue
                    let endDt = result?["endDatetime"]?.stringValue
                        ?? result?["end_datetime"]?.stringValue
                        ?? startDt
                    await AppRepository.createTaskWithRecurrence(
                        title: title,
                        description: desc,
                        labelId: result?["labelId"]?.stringValue,
                        priorityLevelId: result?["priorityLevelId"]?.stringValue,
                        startDatetime: startDt,
                        endDatetime: endDt,
                        location: result?["location"]?.stringValue,
                        subjectUserId: TokenManager.getUserId() ?? "",
                        repeatTypeName: repeatTypeName
                    ).fold(
                        onSuccess: { _ in LogManager.logInfo("Elda task with recurrence created successfully") },
                        onFailure: { LogManager.logError("Elda task with recurrence failed: \($0.message)") }
                    )
                }
            }

            if let dialogId = currentDialogId {
                _ = await AppRepository.sendDialogMessage(dialogId: dialogId, role: "assistant",
                                                         content: replyText)
            }
            responseState = .success(.reply(text: replyText, cards: response.cards ?? []))
        }
    }

    private func ensureDialog() async -> String? {
        let currentUserId = TokenManager.getUserId()

        if currentDialogId != nil, dialogOwnerUserId != nil, dialogOwnerUserId != currentUserId {
            LogManager.logInfo("ensureDialog: user changed, resetting dialog")
            resetDialog()
        }

        if let currentDialogId { return currentDialogId }

        TokenManager.clearDialogId()

        if let dialogId = await AppRepository.createAgentDialog(title: "Chat").getOrNull?.dialogId {
            currentDialogId = dialogId
            dialogOwnerUserId = currentUserId
            TokenManager.saveDialogId(dialogId)
            return dialogId
        }
        responseState = .error("Could not start conversation")
        return nil
    }

    func loadHistory(onLoaded: @escaping ([ChatMessage]) -> Void) {
        let currentUserId = TokenManager.getUserId()

        if dialogOwnerUserId != nil && dialogOwnerUserId != currentUserId {
            LogManager.logInfo("loadHistory: user changed, resetting dialog")
            resetDialog()
            return
        }

        guard let dialogId = currentDialogId else { return }
        dialogOwnerUserId = currentUserId

        Task {
            await AppRepository.listDialogMessages(dialogId: dialogId, limit: 200).onSuccess { messages in
                let chatMessages = messages
                    .filter { ["user", "assistant"].contains($0.role) }
                    .filter { !($0.content.isNullOrBlank) }
                    .filter { !($0.content!.hasPrefix("[Context:")) }
                    .map { msg in
                        ChatMessage(
                            sender: msg.role == "user" ? "You" : "Elda",
                            text: msg.content ?? "",
                            isUser: msg.role == "user",
                            cards: msg.cards ?? []
                        )
                    }
                if !chatMessages.isEmpty { onLoaded(chatMessages) }
            }
        }
    }

    func resetDialog() {
        currentDialogId = nil
        dialogOwnerUserId = nil
        pendingClarificationIntentId = nil
        pendingRecurrenceTypeName = nil
        contextInjected = false
        responseState = .idle
        TokenManager.clearDialogId()
    }

    func resetState() { responseState = .idle }
}
