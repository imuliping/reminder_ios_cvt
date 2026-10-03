//
//  AppRepository.swift
//  Port of shared/Apprepository.kt. Every call is wrapped in Result<T, Error>
//  exactly as `safeCall` did on Android, and the default date windows / userId
//  fallbacks are preserved verbatim.
//

import Foundation

// Kotlin's Result helpers, so the ViewModel call sites read the same.
extension Result {
    var getOrNull: Success? {
        if case .success(let v) = self { return v }
        return nil
    }

    func getOrElse(_ fallback: Success) -> Success {
        getOrNull ?? fallback
    }

    // These take async closures so the ViewModels can await inside them, the way
    // the Kotlin versions could suspend inside `fold { … }`. Passing a plain
    // synchronous closure is still allowed.
    @discardableResult
    func onSuccess(_ action: (Success) async -> Void) async -> Result {
        if case .success(let v) = self { await action(v) }
        return self
    }

    @discardableResult
    func onFailure(_ action: (Failure) async -> Void) async -> Result {
        if case .failure(let e) = self { await action(e) }
        return self
    }

    func fold(onSuccess: (Success) async -> Void, onFailure: (Failure) async -> Void) async {
        switch self {
        case .success(let v): await onSuccess(v)
        case .failure(let e): await onFailure(e)
        }
    }
}

extension Error {
    /// Kotlin's `it.message`
    var message: String { (self as? APIError)?.errorDescription ?? localizedDescription }
}

enum AppRepository {

    private static var api: APIService { APIService.shared }

    private static func safeCall<T>(_ call: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await call()) }
        catch { return .failure(error) }
    }

    // ── Linked changes ─────────────────────────────────────────────
    static func getLinkedChanges() async -> Result<[LinkedChange], Error> {
        await safeCall { try await api.getLinkedChanges() }
    }

    static func getLinkedEmergencyContacts() async -> Result<[EmergencyContact], Error> {
        await safeCall { try await api.getEmergencyContacts(seniorUserId: TokenManager.getSeniorUserId()) }
    }

    static func proposeLinkedChange(_ request: LinkedChangeRequest) async -> Result<LinkedChange, Error> {
        await safeCall { try await api.proposeLinkedChange(request) }
    }

    static func reviewLinkedChange(id: String, approve: Bool) async -> Result<Void, Error> {
        let result = await safeCall {
            if approve { return try await api.approveLinkedChange(id) }
            return try await api.rejectLinkedChange(id)
        }
        return result.map { _ in () }
    }

    // ── Auth ───────────────────────────────────────────────────────
    static func login(email: String, password: String) async -> Result<LoginResponse, Error> {
        await safeCall { try await api.login(username: email, password: password) }
    }

    static func signup(email: String, username: String, age: Int, password: String,
                       passwordConfirmation: String, familyAccountId: String? = nil,
                       roleId: String? = nil) async -> Result<LoginResponse, Error> {
        await safeCall {
            try await api.signup(SignupRequest(
                email: email, username: username, age: age, password: password,
                passwordConfirmation: passwordConfirmation,
                familyAccountId: familyAccountId, roleId: roleId
            ))
        }
    }

    static func getMe() async -> Result<Me, Error> {
        await safeCall { try await api.getMe() }
    }

    static func revokeSession() async -> Result<Void, Error> {
        await safeCall { try await api.revokeSession() }.map { _ in () }
    }

    static func getSessionSettings() async -> Result<SessionSettings, Error> {
        await safeCall { try await api.getSessionSettings() }
    }

    static func setSessionSettings(minutes: Int) async -> Result<SessionSettings, Error> {
        await safeCall { try await api.setSessionSettings(SessionSettings(autoLogoutMinutes: minutes)) }
    }

    static func recordSessionActivity() async -> Result<Void, Error> {
        await safeCall { try await api.recordSessionActivity() }.map { _ in () }
    }

    static func logout() { TokenManager.clearSession() }

    // ── Forgot Password ───────────────────────────────────────────
    static func forgotPasswordRequest(identifier: String, channel: String,
                                      email: String? = nil, phone: String? = nil) async -> Result<ForgotPasswordRequestResponse, Error> {
        await safeCall {
            try await api.forgotPasswordRequest(ForgotPasswordRequest(
                identifier: identifier, channel: channel, email: email, phone: phone))
        }
    }

    static func forgotPasswordVerify(resetRequestId: String, code: String) async -> Result<ForgotPasswordVerifyResponse, Error> {
        await safeCall {
            try await api.forgotPasswordVerify(ForgotPasswordVerifyRequest(
                resetRequestId: resetRequestId, code: code))
        }
    }

    static func forgotPasswordReset(resetRequestId: String, resetToken: String,
                                    password: String, passwordConfirmation: String) async -> Result<String, Error> {
        await safeCall {
            try await api.forgotPasswordReset(ForgotPasswordResetRequest(
                resetRequestId: resetRequestId, resetToken: resetToken,
                password: password, passwordConfirmation: passwordConfirmation))
        }
    }

    // ── Users ──────────────────────────────────────────────────────
    static func updateUser(userId: String, username: String? = nil, email: String? = nil,
                           age: Int? = nil, phone: String? = nil) async -> Result<User, Error> {
        await safeCall {
            try await api.updateUser(userId, UpdateUserRequest(
                username: username, email: email, age: age, phone: phone))
        }
    }

    // ── Tasks ──────────────────────────────────────────────────────
    static func getTasks(date: String? = nil, subjectUserId: String? = nil, userId: String? = nil,
                         includeShopping: Bool? = nil, fromDt: String? = nil,
                         toDt: String? = nil) async -> Result<[TaskItem], Error> {
        await safeCall {
            try await api.getTasks(date: date, subjectUserId: subjectUserId, userId: userId,
                                   includeShopping: includeShopping, fromDt: fromDt, toDt: toDt)
        }
    }

    static func getScheduleTasks(date: String? = nil, subjectUserId: String? = nil,
                                 userId: String? = nil, assignedTo: String? = nil,
                                 createdBy: String? = nil, fromDt: String? = nil,
                                 toDt: String? = nil, unfiltered: Bool = false) async -> Result<[TaskItem], Error> {
        let targetUserId: String? = unfiltered
            ? nil
            : (subjectUserId ?? TokenManager.getSeniorUserId() ?? TokenManager.getUserId())
        let defaultFrom = dayOffsetString(-30)
        let defaultTo   = dayOffsetString(90)
        return await safeCall {
            try await api.getScheduleTasks(
                subjectUserId: (unfiltered || assignedTo != nil || createdBy != nil) ? nil : targetUserId,
                userId: userId,
                assignedTo: assignedTo,
                createdBy: createdBy,
                fromDt: fromDt ?? date ?? defaultFrom,
                toDt: toDt ?? date ?? defaultTo,
                limit: 30
            )
        }
    }

    static func getTodayTasks() async -> Result<[TaskItem], Error> {
        let today = todayString()
        // When the authenticated user IS the senior, use their own userId.
        // getSeniorUserId() points to the senior linked to a family member /
        // caregiver — using it when a senior logs in gives 403.
        let seniorId = TokenManager.isSenior()
            ? (TokenManager.getUserId() ?? "")
            : (TokenManager.getSeniorUserId() ?? "")
        let timeZone = TokenManager.getUserTimeZone() ?? appTimeZoneIdentifier
        let result = await safeCall {
            try await api.getMyDay(date: today, seniorId: seniorId, timezone: timeZone)
        }
        return result.map { response in
            response.groups?.flatMap { $0.tasks } ?? []
        }
    }

    static func createTask(title: String, description: String? = nil, labelId: String? = nil,
                           priorityLevelId: String? = nil, startDatetime: String? = nil,
                           endDatetime: String? = nil, location: String? = nil,
                           assignedToUserId: String? = nil, taskStatusId: String? = nil,
                           notes: String? = nil, subjectUserId: String? = nil) async -> Result<TaskItem, Error> {
        await safeCall {
            try await api.createTask(TaskRequest(
                priorityLevelId: priorityLevelId,
                startDatetime: startDatetime,
                endDatetime: endDatetime,
                location: location,
                taskStatusId: taskStatusId,
                labelId: labelId,
                assignedToUserId: assignedToUserId,
                subjectUserId: subjectUserId ?? TokenManager.getUserId(),
                title: title,
                description: description,
                notes: notes,
                familyAccountId: TokenManager.getFamilyAccountId()
            ))
        }
    }

    static func assignTaskToUser(taskId: String, userId: String,
                                 taskRoleId: String? = nil) async -> Result<Void, Error> {
        let r = await safeCall {
            try await api.createTaskAssignment(TaskAssignmentRequest(
                taskId: taskId, userId: userId, taskRoleId: taskRoleId))
        }
        return r.map { _ in () }
    }

    static func updateTask(taskId: String, title: String? = nil, description: String? = nil,
                           labelId: String? = nil, priorityLevelId: String? = nil,
                           startDatetime: String? = nil, endDatetime: String? = nil,
                           location: String? = nil, taskStatusId: String? = nil,
                           notes: String? = nil, hiddenFromFamily: Bool? = nil) async -> Result<TaskItem, Error> {
        await safeCall {
            try await api.updateTask(taskId, TaskRequest(
                priorityLevelId: priorityLevelId,
                startDatetime: startDatetime,
                endDatetime: endDatetime,
                location: location,
                taskStatusId: taskStatusId,
                labelId: labelId,
                title: title,
                description: description,
                notes: notes,
                hiddenFromFamily: hiddenFromFamily
            ))
        }
    }

    static func setTaskFamilyVisibility(taskId: String, hidden: Bool) async -> Result<TaskItem, Error> {
        await safeCall {
            try await api.updateTask(taskId, TaskRequest(hiddenFromFamily: hidden))
        }
    }

    // PUT /api/v1/tasks/{taskId}/repeated-tasks
    // fromDatetime = nil  → update ALL instances (past + future)
    // fromDatetime = <dt> → update from that datetime forward ("this and future")
    static func updateRepeatedTasks(taskId: String, title: String? = nil, description: String? = nil,
                                    labelId: String? = nil, priorityLevelId: String? = nil,
                                    startDatetime: String? = nil, endDatetime: String? = nil,
                                    location: String? = nil, fromDatetime: String? = nil) async -> Result<Void, Error> {
        let r = await safeCall {
            try await api.updateRepeatedTasks(taskId, UpdateRepeatedTasksRequest(
                changes: RepeatedTaskChanges(
                    title: title, name: title, description: description,
                    labelId: labelId, priorityLevelId: priorityLevelId,
                    startDatetime: startDatetime, endDatetime: endDatetime, location: location
                ),
                fromDatetime: fromDatetime
            ))
        }
        return r.map { _ in () }
    }

    /// Stops a recurring series — deletes all repeated instances.
    static func deleteRepeatedTasks(taskId: String) async -> Result<Void, Error> {
        await safeCall { try await api.deleteRepeatedTasks(taskId, DeleteRepeatedTasksRequest()) }
    }

    /// Deletes only future instances from now onward — "Stop Repeating".
    /// Past completed instances are preserved.
    static func stopFutureRepeatedTasks(taskId: String) async -> Result<Void, Error> {
        let fromNow = nowDatetimeString()
        return await safeCall {
            try await api.deleteRepeatedTasks(taskId, DeleteRepeatedTasksRequest(fromDatetime: fromNow))
        }
    }

    static func completeTask(taskId: String, note: String? = nil) async -> Result<TaskItem, Error> {
        await safeCall { try await api.completeTask(taskId, CompleteTaskRequest(note: note)).task }
    }

    static func skipTask(taskId: String) async -> Result<TaskItem, Error> {
        await safeCall { try await api.skipTask(taskId).task }
    }

    static func getTask(taskId: String) async -> Result<TaskItem, Error> {
        await safeCall { try await api.getTask(taskId) }
    }

    static func deleteTask(taskId: String) async -> Result<Void, Error> {
        let r = await safeCall { try await api.deleteTask(taskId) }
        return r.map { _ in () }
    }

    static func getUpcomingScheduleTasks(subjectUserId: String? = nil,
                                         userId: String? = nil) async -> Result<[TaskItem], Error> {
        await safeCall {
            try await api.getUpcomingScheduleTasks(subjectUserId: subjectUserId, userId: userId,
                                                   includeShopping: false)
        }
    }

    static func getUpcomingTodoListTasks(subjectUserId: String? = nil,
                                         userId: String? = nil) async -> Result<[TaskItem], Error> {
        await safeCall {
            try await api.getUpcomingTodoListTasks(subjectUserId: subjectUserId, userId: userId,
                                                   includeShopping: false)
        }
    }

    static func getTodoListTasks(subjectUserId: String? = nil, fromDt: String? = nil,
                                 toDt: String? = nil, assignedTo: String? = nil,
                                 createdBy: String? = nil, unfiltered: Bool = false) async -> Result<[TaskItem], Error> {
        let targetUserId: String? = unfiltered
            ? nil
            : (subjectUserId ?? TokenManager.getSeniorUserId() ?? TokenManager.getUserId())
        return await safeCall {
            try await api.getTodoListTasks(
                subjectUserId: (unfiltered || assignedTo != nil || createdBy != nil) ? nil : targetUserId,
                limit: 30,
                fromDt: fromDt ?? dayOffsetString(-30),
                toDt: toDt ?? dayOffsetString(90),
                assignedTo: assignedTo,
                createdBy: createdBy
            )
        }
    }

    // ── Shopping ───────────────────────────────────────────────────
    static func getShoppingTasks(groceryLabelId: String? = nil,
                                 subjectUserId: String? = nil) async -> Result<[TaskItem], Error> {
        let targetUserId = subjectUserId
            ?? TokenManager.getSeniorUserId()
            ?? TokenManager.getUserId()
        let r = await safeCall {
            try await api.getShoppingList(subjectUserId: targetUserId, includeShopping: true, limit: 50)
        }
        return r.map { tasks in
            guard let groceryLabelId else { return tasks }
            return tasks.filter { $0.labelId == groceryLabelId }
        }
    }

    static func createShoppingTask(itemName: String, description: String? = nil,
                                   location: String? = nil, groceryLabelId: String? = nil,
                                   priorityLevelId: String? = nil,
                                   dueDatetime: String? = nil) async -> Result<TaskItem, Error> {
        await createTask(
            title: itemName,
            description: description,
            labelId: groceryLabelId,
            priorityLevelId: priorityLevelId,
            startDatetime: dueDatetime,
            endDatetime: dueDatetime.map { $0.take(10) + "T23:59:59" },
            location: location,
            subjectUserId: TokenManager.getUserId()
        )
    }

    static func markShoppingItemBought(taskId: String) async -> Result<TaskItem, Error> {
        await completeTask(taskId: taskId)
    }

    // ── User Settings: Time Zone ───────────────────────────────────
    static func getMyTimeZone() async -> Result<TimeZoneResponse, Error> {
        await safeCall { try await api.getMyTimeZone() }
    }

    static func updateMyTimeZone(timeZone: String) async -> Result<TimeZoneResponse, Error> {
        await safeCall { try await api.putMyTimeZone(UpdateTimeZoneRequest(timeZone: timeZone)) }
    }

    // ── Notifications ──────────────────────────────────────────────
    static func getNotificationInbox() async -> Result<[NotificationInboxItem], Error> {
        await safeCall { try await api.getNotificationInbox() }
    }

    static func getNotification(notificationId: String) async -> Result<NotificationInboxItem, Error> {
        await safeCall { try await api.getNotification(notificationId).notification }
    }

    static func completeNotification(notificationId: String) async -> Result<NotificationInboxItem, Error> {
        await safeCall { try await api.completeNotification(notificationId) }
    }

    static func cannotDoNotification(notificationId: String) async -> Result<NotificationInboxItem, Error> {
        await safeCall {
            try await api.completeNotification(
                notificationId, NotificationActionRequest(actionStatus: "cannot_do"))
        }
    }

    static func acknowledgeNotification(notificationId: String) async -> Result<NotificationInboxItem, Error> {
        await safeCall { try await api.acknowledgeNotification(notificationId) }
    }

    static func dismissNotification(notificationId: String) async -> Result<Void, Error> {
        let r = await safeCall {
            try await api.dismissNotification(notificationId, DismissNotificationRequest(note: ""))
        }
        return r.map { _ in () }
    }

    static func snoozeNotification(notificationId: String, minutes: Int) async -> Result<Void, Error> {
        let r = await safeCall {
            try await api.snoozeNotification(notificationId, SnoozeNotificationRequest(minutes: minutes))
        }
        return r.map { _ in () }
    }

    // ── Emergency Contacts ─────────────────────────────────────────
    static func getEmergencyContacts() async -> Result<[EmergencyContact], Error> {
        await safeCall { try await api.getEmergencyContacts() }
    }

    static func createEmergencyContact(name: String, phone: String, relation: String?,
                                       order: Int? = nil, smsEnabled: Bool = false,
                                       userId: String? = nil) async -> Result<EmergencyContact, Error> {
        await safeCall {
            try await api.createEmergencyContact(CreateEmergencyContactRequest(
                name: name, phone: phone, relation: relation, order: order,
                smsEnabled: smsEnabled, userId: userId))
        }
    }

    static func addSmsEmergencyContact(name: String, phone: String) async -> Result<EmergencyContact, Error> {
        await createEmergencyContact(name: name, phone: phone, relation: "Emergency",
                                     smsEnabled: true, userId: TokenManager.getSeniorUserId())
    }

    static func enableEmergencyContactSms(id: String) async -> Result<EmergencyContact, Error> {
        await safeCall {
            try await api.updateEmergencyContact(id, UpdateEmergencyContactRequest(smsEnabled: true))
        }
    }

    static func deleteEmergencyContact(id: String) async -> Result<String, Error> {
        await safeCall { try await api.deleteEmergencyContact(id) }
    }

    // ── Team Chat ──────────────────────────────────────────────────
    static func getTeamChatMessages(familyAccountId: String) async -> Result<[TeamChatMessage], Error> {
        await safeCall { try await api.getTeamChatMessages(familyAccountId: familyAccountId) }
    }

    static func sendTeamChatMessage(content: String, familyAccountId: String) async -> Result<TeamChatMessage, Error> {
        await safeCall { try await api.sendTeamChatMessage(SendTeamChatMessageRequest(content: content)) }
    }

    // ── Agent ──────────────────────────────────────────────────────
    static func createAgentDialog(title: String) async -> Result<AgentDialogSummary, Error> {
        await safeCall { try await api.createAgentDialog(CreateDialogRequest(title: title)) }
    }

    static func listAgentDialogs() async -> Result<[AgentDialogSummary], Error> {
        await safeCall { try await api.listAgentDialogs() }
    }

    static func sendDialogMessage(dialogId: String, role: String, content: String) async -> Result<String, Error> {
        await safeCall {
            try await api.createDialogMessage(dialogId, CreateDialogMessageRequest(role: role, content: content))
        }
    }

    static func sendTextAction(text: String, dialogId: String?, execute: Bool = true,
                               pendingIntentId: String? = nil) async -> Result<TextActionResponse, Error> {
        await safeCall {
            try await api.sendTextAction(TextActionRequest(
                text: text, execute: execute, dialogId: dialogId,
                pendingIntentId: pendingIntentId))
        }
    }

    static func listDialogMessages(dialogId: String, limit: Int = 200) async -> Result<[AgentDialogMessage], Error> {
        await safeCall { try await api.listDialogMessages(dialogId, limit: limit) }
    }

    static func sendVoiceAction(file: URL, dialogId: String? = nil) async -> Result<TextActionResponse, Error> {
        await safeCall {
            if let dialogId {
                return try await api.sendDialogVoiceAction(dialogId, audio: file, execute: "true", language: "en")
            }
            return try await api.sendVoiceAction(audio: file, execute: "true", dialogId: nil, language: "en")
        }
    }

    static func confirmIntent(pendingIntentId: String) async -> Result<TextActionResponse, Error> {
        await safeCall { try await api.confirmIntent(ConfirmIntentRequest(pendingIntentId: pendingIntentId)) }
    }

    // ── User Notification Policy ───────────────────────────────────
    static func getMyNotificationPolicies(priorityLevelId: String? = nil,
                                          taskRoleId: String? = nil) async -> Result<[NotificationPolicy], Error> {
        await safeCall {
            try await api.getMyNotificationPolicies(priorityLevelId: priorityLevelId, taskRoleId: taskRoleId)
        }
    }

    static func createMyNotificationPolicy(_ request: CreateNotificationPolicyRequest) async -> Result<NotificationPolicy, Error> {
        await safeCall { try await api.createMyNotificationPolicy(request) }
    }

    static func updateMyNotificationPolicy(id: String, request: UpdateNotificationPolicyRequest) async -> Result<NotificationPolicy, Error> {
        await safeCall { try await api.updateMyNotificationPolicy(id, request) }
    }

    static func saveCheckInRecipients(priorityId: String, policyId: String?,
                                      users: [String], contacts: [String]) async -> Result<NotificationPolicy, Error> {
        let request = CheckInRecipientsRequest(
            priorityLevelId: priorityId,
            escalateToUserIds: users,
            escalateToEmergencyContactIds: contacts)
        if let policyId {
            return await safeCall { try await api.updateCheckInRecipients(policyId, request) }
        }
        return await safeCall { try await api.createCheckInRecipients(request) }
    }

    // ── Reports ────────────────────────────────────────────────────
    static func getWeeklySummary(seniorUserId: String? = nil,
                                 weekStart: String? = nil) async -> Result<WeeklySummaryData, Error> {
        await safeCall {
            let r = try await api.getWeeklySummary(seniorUserId: seniorUserId, weekStart: weekStart)
            return WeeklySummaryData(
                seniorUserId: r.seniorUserId,
                weekStart: r.weekStart,
                weekEnd: r.weekEnd,
                weeklySummary: r.weeklySummary.map {
                    WeeklySummaryStats(
                        medicationAdherencePct: $0.medicationAdherencePct,
                        criticalMissedTasksCount: $0.criticalMissedTasksCount,
                        appointmentsKept: $0.appointmentsKept,
                        appointmentsTotal: $0.appointmentsTotal,
                        caregiverVisitsCompleted: $0.caregiverVisitsCompleted
                    )
                },
                medicationAdherence: r.medicationAdherence.map {
                    MedicationAdherenceData(
                        prescribedMedications: $0.prescribedMedications,
                        takenOnTimePct: $0.takenOnTimePct,
                        takenLatePct: $0.takenLatePct,
                        missedPct: $0.missedPct,
                        escalationsTriggered: $0.escalationsTriggered,
                        insightBadge: $0.insightBadge
                    )
                },
                dailyRoutineStability: r.dailyRoutineStability.map {
                    DailyRoutineStability(
                        indicators: $0.indicators?.map { RoutineIndicator(name: $0.name, status: $0.status) }
                    )
                },
                appointmentReliability: r.appointmentSchedule.map {
                    AppointmentReliability(scheduled: $0.scheduled, attended: $0.attended,
                                           late: $0.late, missed: $0.missed)
                },
                // Embedded escalations from the summary response — no separate call needed
                escalations: r.alertsEscalationHistory?.map {
                    EscalationItem(date: $0.date, task: $0.task, level: $0.level, action: $0.action)
                } ?? []
            )
        }
    }

    static func getEscalations(limit: Int = 100) async -> Result<[EscalationItem], Error> {
        await safeCall {
            try await api.getEscalations(limit: limit).map {
                EscalationItem(date: $0.date, task: $0.task, level: $0.level, action: $0.action)
            }
        }
    }

    // ── Valid Types ────────────────────────────────────────────────
    static func getLabels() async -> Result<[TaskLabel], Error> {
        await safeCall { try await api.getLabels() }
    }

    static func getPriorityLevels() async -> Result<[PriorityLevel], Error> {
        await safeCall { try await api.getPriorityLevels() }
    }

    static func getRecurrenceTypes() async -> Result<[RecurrenceType], Error> {
        await safeCall { try await api.getRecurrenceTypes() }
    }

    // ── Recurrence ─────────────────────────────────────────────────
    static func getRecurrenceRulesForTask(taskId: String) async -> Result<[RecurrenceRule], Error> {
        await safeCall { try await api.getRecurrenceRules(sourceTaskId: taskId) }
    }

    /// POST /api/v1/tasks/with-recurrence — creates task + rule + weekday patterns
    /// in one call. `repeatTypeName` is the lowercase name, e.g. "daily".
    static func createTaskWithRecurrence(title: String, description: String?, labelId: String?,
                                         priorityLevelId: String?, startDatetime: String,
                                         endDatetime: String, location: String?,
                                         subjectUserId: String?, repeatTypeName: String,
                                         selectedWeekdays: [String]? = nil,
                                         repeatEvery: Int = 1,
                                         lookaheadDays: Int = 30) async -> Result<TaskItem, Error> {
        await safeCall {
            let patterns = recurrencePatternsFor(repeatTypeName, startDatetime, selectedWeekdays)
                .map { RecurrencePatternItem(weekdayId: $0) }
            let response = try await api.createTaskWithRecurrence(CreateTaskWithRecurrenceRequest(
                title: title,
                description: description,
                labelId: labelId?.nonBlank,
                priorityLevelId: priorityLevelId?.nonBlank,
                startDatetime: startDatetime,
                endDatetime: endDatetime,
                location: location,
                subjectUserId: subjectUserId,
                familyAccountId: TokenManager.getFamilyAccountId(),
                recurrence: RecurrenceSpec(
                    repeatTypeId: repeatTypeName.lowercased(),
                    repeatEvery: repeatEvery,
                    timeOfDay: timeOfDayFromDatetime(startDatetime),
                    timezone: TokenManager.getUserTimeZone() ?? appTimeZoneIdentifier,
                    isActive: true
                ),
                recurrencePatterns: patterns,
                lookaheadDays: lookaheadDays
            ))
            return response.task   // unwrap { ok, task, recurrenceRule, generatedTasks }
        }
    }

    /// PUT /api/v1/tasks/{taskId}/with-recurrence
    static func updateTaskWithRecurrence(taskId: String, title: String, description: String?,
                                         labelId: String?, priorityLevelId: String?,
                                         startDatetime: String, endDatetime: String,
                                         location: String?, repeatTypeName: String,
                                         selectedWeekdays: [String]? = nil,
                                         repeatEvery: Int = 1,
                                         lookaheadDays: Int = 30) async -> Result<TaskItem, Error> {
        await safeCall {
            let patterns = selectedWeekdays.map {
                recurrencePatternsFor(repeatTypeName, startDatetime, $0)
                    .map { RecurrencePatternItem(weekdayId: $0) }
            }
            return try await api.updateTaskWithRecurrence(taskId, CreateTaskWithRecurrenceRequest(
                title: title,
                description: description,
                labelId: labelId?.nonBlank,
                priorityLevelId: priorityLevelId?.nonBlank,
                startDatetime: startDatetime,
                endDatetime: endDatetime,
                location: location,
                subjectUserId: nil,
                familyAccountId: TokenManager.getFamilyAccountId(),
                recurrence: RecurrenceSpec(
                    repeatTypeId: repeatTypeName.lowercased(),
                    repeatEvery: repeatEvery,
                    timeOfDay: timeOfDayFromDatetime(startDatetime),
                    timezone: TokenManager.getUserTimeZone() ?? appTimeZoneIdentifier,
                    isActive: true
                ),
                recurrencePatterns: patterns,
                lookaheadDays: lookaheadDays
            ))
        }
    }

    // ── Recurrence helpers (private) ───────────────────────────────
    private static func weekdayIdFromDatetime(_ startDatetime: String) -> String? {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = userTimeZone()
        guard let date = f.date(from: startDatetime.take(19)) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = userTimeZone()
        switch calendar.component(.weekday, from: date) {
        case 1:  return "SUN"
        case 2:  return "MON"
        case 3:  return "TUE"
        case 4:  return "WED"
        case 5:  return "THU"
        case 6:  return "FRI"
        case 7:  return "SAT"
        default: return nil
        }
    }

    private static func timeOfDayFromDatetime(_ startDatetime: String) -> String {
        let parts = startDatetime.split(separator: "T", maxSplits: 1).map(String.init)
        guard parts.count > 1 else { return "09:00" }
        return parts[1].take(5)
    }

    private static func recurrencePatternsFor(_ repeatTypeName: String, _ startDatetime: String,
                                              _ selectedWeekdays: [String]? = nil) -> [String] {
        guard repeatTypeName.lowercased() == "weekly" else { return [] }
        if let selectedWeekdays, !selectedWeekdays.isEmpty { return selectedWeekdays }
        guard let weekdayId = weekdayIdFromDatetime(startDatetime) else { return [] }
        return [weekdayId]
    }

    // ── Family Tasks ───────────────────────────────────────────────
    static func getMyFamilyTasks() async -> Result<[TaskItem], Error> {
        await safeCall { try await api.getMyFamilyTasks() }
    }

    // ── Task Assignment Offers ─────────────────────────────────────
    static func getAssignmentCandidates(taskId: String? = nil) async -> Result<[TaskAssignmentCandidate], Error> {
        await safeCall { try await api.getAssignmentCandidates(taskId: taskId) }
    }

    static func createAssignmentOffer(taskId: String, toUserId: String, message: String? = nil,
                                      expiresInMinutes: Int = 60) async -> Result<TaskAssignmentOffer, Error> {
        await safeCall {
            try await api.createAssignmentOffer(TaskAssignmentOfferRequest(
                taskId: taskId, toUserId: toUserId, message: message,
                expiresInMinutes: expiresInMinutes))
        }
    }

    static func getMyOffers(status: String? = nil) async -> Result<[TaskAssignmentOffer], Error> {
        await safeCall { try await api.getMyOffers(status: status) }
    }

    static func getOffersForTask(taskId: String) async -> Result<[TaskAssignmentOffer], Error> {
        await safeCall { try await api.getOffersForTask(taskId) }
    }

    static func acceptOffer(offerId: String) async -> Result<TaskAssignmentOffer, Error> {
        await safeCall { try await api.acceptOffer(offerId, body: [:]) }
    }

    static func declineOffer(offerId: String) async -> Result<TaskAssignmentOffer, Error> {
        await safeCall { try await api.declineOffer(offerId, body: [:]) }
    }

    static func cancelOffer(offerId: String) async -> Result<TaskAssignmentOffer, Error> {
        await safeCall { try await api.cancelOffer(offerId) }
    }

    static func getMySeniors() async -> Result<[SeniorInfo], Error> {
        await safeCall { try await api.getMySeniors() }
    }

    static func registerDevice(token: String) async -> Result<DeviceResponse, Error> {
        await safeCall { try await api.registerDevice(RegisterDeviceRequest(token: token, platform: "ios")) }
    }

    static func unregisterDevice(deviceId: String) async -> Result<Void, Error> {
        await safeCall { try await api.deleteDevice(deviceId) }.map { _ in () }
    }

    // ── Program Settings ───────────────────────────────────────────
    static func getProgramSettings() async -> Result<ProgramSettings, Error> {
        await safeCall { try await api.getProgramSettings() }
    }

    static func updateProgramSettings(_ settings: ProgramSettings) async -> Result<ProgramSettings, Error> {
        var copy = settings
        copy._id = nil
        copy.userId = nil
        copy.familyAccountId = nil
        return await safeCall { try await api.updateProgramSettings(copy) }
    }

    static func deleteProgramSettings(section: String = "all") async -> Result<Void, Error> {
        await safeCall { try await api.deleteProgramSettings(section: section) }
    }

    static func resetProgramSettings() async -> Result<ProgramSettings, Error> {
        await safeCall { try await api.resetProgramSettings() }
    }

    static func getFamily(familyAccountId: String) async -> Result<FamilyDetailResponse, Error> {
        await safeCall { try await api.getFamily(familyAccountId) }
    }

    static func removeFamilyMember(familyAccountId: String, userId: String) async -> Result<Void, Error> {
        let r = await safeCall { try await api.removeFamilyMember(familyAccountId, userId) }
        return r.map { _ in () }
    }

    static func createInvite(familyAccountId: String, roleId: String,
                             destination: String = "",
                             permissions: LinkedPermissions = LinkedPermissions()) async -> Result<String, Error> {
        let email = destination.contains("@") ? destination : nil
        let phone = destination.isBlank || email != nil ? nil : destination
        let r = await safeCall {
            try await api.createInvite(familyAccountId, CreateInviteRequest(
                role: roleId, email: email, phone: phone, permissions: permissions))
        }
        switch r {
        case .success(let invite):
            guard let token = invite.token else {
                return .failure(APIError.decoding("No invite token in response"))
            }
            return .success(token)
        case .failure(let e):
            return .failure(e)
        }
    }

    static func acceptInvite(token: String) async -> Result<String, Error> {
        let r = await safeCall { try await api.acceptInvite(AcceptInviteRequest(token: token)) }
        return r.map { $0.message ?? "Joined successfully" }
    }

    static func updateLinkedMember(familyId: String, userId: String, role: String,
                                   permissions: LinkedPermissions) async -> Result<Void, Error> {
        let result = await safeCall {
            if role == RoleIds.FAMILY {
                _ = try await api.updateLinkedPermissions(familyId, userId, permissions)
            } else {
                _ = try await api.updateLinkedRole(familyId, userId, MemberRoleRequest(role: role))
            }
        }
        return result
    }
}

extension String {
    /// Kotlin's `takeIf { it.isNotBlank() }`
    var nonBlank: String? { isBlank ? nil : self }
}

// ─────────────────────────────────────────────────────────────────
//  Device token registration — the APNs equivalent of the
//  registerDeviceToken()/unregisterDeviceToken() helpers that lived in
//  shared/SCTFirebaseMessagingServices.kt.
// ─────────────────────────────────────────────────────────────────

func registerDeviceToken(_ token: String) async {
    await AppRepository.registerDevice(token: token).fold(
        onSuccess: { device in
            TokenManager.saveDeviceId(device.deviceId ?? "")
            LogManager.logInfo("Device registered: \(device.deviceId ?? "")")
        },
        onFailure: { LogManager.logError("Failed to register device: \($0.message)") }
    )
}

func unregisterDeviceToken() async {
    guard let deviceId = TokenManager.getDeviceId() else { return }
    await AppRepository.unregisterDevice(deviceId: deviceId).fold(
        onSuccess: { _ in LogManager.logInfo("Device unregistered") },
        onFailure: { LogManager.logError("Failed to unregister device: \($0.message)") }
    )
    TokenManager.clearDeviceId()
}
