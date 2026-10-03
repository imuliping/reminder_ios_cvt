//
//  Models.swift
//  Port of app/src/main/java/com/example/sct/shared/Network.kt (data classes).
//
//  Naming notes: the Kotlin `Task` and `Label` names collide with Swift's
//  `Task` (concurrency) and SwiftUI's `Label`, so they are `TaskItem` and
//  `TaskLabel` here. Every other type keeps its Kotlin name. Field names
//  match the backend JSON exactly (camelCase, like Gson's default), so no
//  key-decoding strategy is needed.
//

import Foundation

// ── A loosely-typed JSON value, standing in for Gson's JsonElement / Map<String, Any>
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    /// Mirrors Kotlin's `response.result?.get("x")?.toString()`.
    var stringValue: String? {
        switch self {
        case .string(let v): return v
        case .number(let v): return v == v.rounded() ? String(Int(v)) : String(v)
        case .bool(let v):   return String(v)
        case .null:          return nil
        default:             return nil
        }
    }
}

// ── Auth ──────────────────────────────────────────────────────────
struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let role: String?
    let userType: String?
    let autoLogoutMinutes: Int

    enum CodingKeys: String, CodingKey {
        case accessToken, tokenType, role, userType, autoLogoutMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        userType = try container.decodeIfPresent(String.self, forKey: .userType)
        autoLogoutMinutes = try container.decodeIfPresent(Int.self, forKey: .autoLogoutMinutes) ?? 0
    }

    init(accessToken: String, tokenType: String?, role: String?,
         userType: String?, autoLogoutMinutes: Int = 0) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.role = role
        self.userType = userType
        self.autoLogoutMinutes = autoLogoutMinutes
    }
}

struct SessionSettings: Codable { var autoLogoutMinutes: Int = 0 }

struct SignupRequest: Codable {
    let email: String?
    let username: String
    let age: Int
    let password: String
    let passwordConfirmation: String
    var familyAccountId: String? = nil
    var roleId: String? = nil
    var phone: String? = nil
}

// ── Forgot Password ───────────────────────────────────────────────
struct ForgotPasswordRequest: Codable {
    let identifier: String
    let channel: String
    var email: String? = nil
    var phone: String? = nil
}

struct ForgotPasswordRequestResponse: Codable {
    let resetRequestId: String
    let deliveryChannel: String?
    let destination: String?
    let expiresAt: String?
    let pendingContact: Bool?
}

struct ForgotPasswordVerifyRequest: Codable {
    let resetRequestId: String
    let code: String
}

struct ForgotPasswordVerifyResponse: Codable {
    let resetRequestId: String
    let resetToken: String
    let tokenExpiresAt: String?
}

struct ForgotPasswordResetRequest: Codable {
    let resetRequestId: String
    let resetToken: String
    let password: String
    let passwordConfirmation: String
}

// ── Me / User ─────────────────────────────────────────────────────
struct Me: Codable {
    let id: String?
    let userId: String?
    let email: String?
    let username: String
    let name: String?
    var phone: String? = nil
    let age: Int?
    let roleId: String?
    let familyAccountId: String?
    let timeZone: String?
    let createdAt: String?
    let updatedAt: String?
}

struct User: Codable {
    let id: String?
    let userId: String?
    let email: String
    let username: String
    let age: Int?
    var phone: String? = nil
    let createdAt: String?
    let modifiedAt: String?
}

struct UpdateUserRequest: Codable {
    let username: String?
    let email: String?
    let age: Int?
    var phone: String? = nil
}

// ── Parent Tasks ──────────────────────────────────────────────────
struct ParentTask: Codable {
    let parentTaskId: String
    let title: String?
    let shortDescription: String?
    let description: String?
    let labelId: String?
    let priorityLevelId: String?
    let startDatetime: String?
    let endDatetime: String?
    let location: String?
    let createdByUserId: String?
    let createdAt: String?
    let updatedAt: String?

    var displayName: String {
        if let t = title, !t.isBlank { return t }
        if let s = shortDescription, !s.isBlank { return s }
        if let d = description, !d.isBlank { return d }
        return "Untitled"
    }
}

// ── Tasks ─────────────────────────────────────────────────────────
struct TaskItem: Codable, Identifiable, Hashable {
    let taskId: String
    let title: String?
    let parentTaskId: String?
    let shortDescription: String?
    let description: String?
    let notes: String?
    let detail: String?
    let details: String?
    let name: String?
    let labelId: String?
    let priorityLevelId: String?
    let startDatetime: String?
    let endDatetime: String?
    let location: String?
    let status: String?
    let taskStatusId: String?
    let assignedToUserId: String?
    let subjectUserId: String?
    let familyAccountId: String?
    let shoppingDetailId: String?
    let createdByUserId: String?
    let createdAt: String?
    let updatedAt: String?
    var isRepeatable: Bool? = nil
    var isSeriesSource: Bool? = nil
    var recurrenceRuleId: String? = nil
    var priorityLevel: Int? = nil
    var detailsVisible: Bool? = nil
    var canEdit: Bool? = nil
    var canComplete: Bool? = nil
    var canSuggest: Bool? = nil
    var hiddenFromFamily: Bool? = nil

    var id: String { taskId }

    var displayName: String {
        if let t = title, !t.isBlank { return t }
        if let s = shortDescription, !s.isBlank { return s }
        if let n = name, !n.isBlank { return n }
        if let d = description, !d.isBlank { return d }
        return "Untitled"
    }

    /// Port of Task.isOverdue() — compares against "now" in the user's saved timezone.
    var isOverdue: Bool {
        if let s = (status ?? taskStatusId)?.lowercased(),
           ["completed", "done", "skipped", "canceled", "cancelled"].contains(s) {
            return false
        }
        guard let due = startDatetime ?? endDatetime,
              let taskTime = parseChatDate(due) else { return false }
        return taskTime < Date()
    }

    var statusText: String {
        switch (status ?? taskStatusId)?.lowercased() {
        case "completed", "done": return "Completed"
        case "skipped": return "Skipped"
        case "missed": return "Missed"
        case "canceled", "cancelled": return "Canceled"
        case "started", "in_progress": return "In progress"
        default: return isOverdue ? "Overdue" : "Scheduled"
        }
    }
}

// ── Task Request ──────────────────────────────────────────────────
struct TaskRequest: Codable {
    var taskId: String? = nil
    var parentTaskId: String? = nil
    var priorityLevelId: String? = nil
    var startDatetime: String? = nil
    var endDatetime: String? = nil
    var location: String? = nil
    var taskStatusId: String? = nil
    var labelId: String? = nil
    var assignedToUserId: String? = nil
    var subjectUserId: String? = nil
    var shoppingDetailId: String? = nil
    var title: String? = nil
    var name: String? = nil
    var description: String? = nil
    var detail: String? = nil
    var notes: String? = nil
    var familyAccountId: String? = nil
    var hiddenFromFamily: Bool? = nil
}

struct CompleteTaskRequest: Codable {
    var note: String? = nil
    var source: String? = nil
}

// ── Notifications ─────────────────────────────────────────────────
struct NotificationInboxItem: Codable, Identifiable {
    let id: String?
    let notificationId: String
    let type: String?
    let voiceText: String?
    let sourceType: String?
    let sourceId: String?
    let scheduledTime: String?
    let ackStatus: String?
    let actionStatus: String?
    let failureReason: String?
    let meta: NotificationMeta?
    let createdAt: String?
    let updatedAt: String?
    var title: String? = nil
    var taskId: String? = nil
    var taskAvailable: Bool? = nil
    var taskStatus: String? = nil
    var taskStartDatetime: String? = nil
    var taskEndDatetime: String? = nil
    var taskDueDate: String? = nil
    var snoozedUntil: String? = nil
    var isCheckIn: Bool? = nil
    var checkInMessage: String? = nil

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case notificationId, type, voiceText, sourceType, sourceId, scheduledTime
        case ackStatus, actionStatus, failureReason, meta, createdAt, updatedAt, title
        case taskId, taskAvailable, taskStatus, taskStartDatetime, taskEndDatetime, taskDueDate
        case snoozedUntil, isCheckIn, checkInMessage
    }

    var displayTitle: String? {
        title
            ?? meta?.taskTitle
            ?? type?.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }
    var body: String? { meta?.body ?? voiceText }
    var acknowledged: Bool {
        let s = ackStatus?.lowercased()
        return s == "acknowledged" || s == "success"
    }
    var escalated: Bool { isCheckIn == true || actionStatus?.lowercased() == "escalated" }
    var linkedTaskId: String? {
        taskId ?? meta?.taskId
            ?? (["task", "tasks"].contains(sourceType ?? "") ? sourceId : nil)
    }
    var hasUnavailableTask: Bool { linkedTaskId != nil && taskAvailable == false }
}

struct NotificationMeta: Codable {
    let alarmId: String?
    let reminderId: String?
    let taskId: String?
    let taskTitle: String?
    let body: String?
}

struct NotificationFeedItem: Codable {
    let notificationId: String
    let title: String?
    let body: String?
    let type: String?
    let sourceId: String?
    let scheduledTime: String?
    let acknowledged: Bool
    let createdAt: String?
}

struct DismissNotificationRequest: Codable { var note: String = "" }
struct SnoozeNotificationRequest: Codable { let minutes: Int }
struct AckNotificationRequest: Codable {
    var signal: String = "acknowledged"
    var note: String? = nil
}
struct NotificationActionRequest: Codable { var actionStatus: String = "completed" }
struct NotificationDetailResponse: Codable { let notification: NotificationInboxItem }
struct TaskStatusResponse: Codable { let task: TaskItem }

// ── Emergency Contacts ────────────────────────────────────────────
struct EmergencyContact: Codable, Identifiable {
    let contactId: String?
    let id: String?
    let familyAccountId: String?
    let userId: String?
    let order: Int?
    let name: String
    let phone: String
    let relation: String?
    let createdAt: String?
    let updatedAt: String?
    var smsEnabled: Bool = false
}

struct CreateEmergencyContactRequest: Codable {
    let name: String
    let phone: String
    let relation: String?
    var order: Int? = nil
    var smsEnabled: Bool = false
    var userId: String? = nil
}

struct UpdateEmergencyContactRequest: Codable {
    var name: String? = nil
    var phone: String? = nil
    var relation: String? = nil
    var order: Int? = nil
    var smsEnabled: Bool? = nil
}

struct CheckInRecipientsRequest: Codable {
    var priorityLevelId: String? = nil
    let escalateToUserIds: [String]
    let escalateToEmergencyContactIds: [String]
    var enabled: Bool = true
}

// ── Team Chat ─────────────────────────────────────────────────────
struct TeamChatMessage: Codable, Identifiable {
    let messageId: String
    let senderId: String?
    let senderUserId: String?
    let senderName: String?
    let senderDisplayName: String?
    let content: String
    let timestamp: String?
    let createdAt: String?
    var familyAccountId: String? = nil

    var id: String { messageId }
}

struct SendTeamChatMessageRequest: Codable {
    let content: String
    var messageType: String = "text"
}

// ── Alarms ────────────────────────────────────────────────────────
struct Alarm: Codable {
    let alarmId: String
    let taskId: String?
    let title: String?
    let scheduledTime: String?
    let isActive: Bool
    let type: String?
}

// ── Agent ─────────────────────────────────────────────────────────
struct AgentDialog: Codable {
    let dialogId: String
    let messages: [AgentDialogMessage]?
    let createdAt: String?
    let updatedAt: String?
}

struct AgentDialogMessage: Codable {
    let role: String
    let content: String?
    let timestamp: String?
    var messageId: String? = nil
    var result: [String: JSONValue]? = nil
    var parsedAction: JSONValue? = nil
    var cards: [ConversationCard]? = nil
}

struct TextActionResponse: Codable {
    let assistantReply: String?
    let transcript: String?
    let executedAction: String?
    let needsConfirmation: Bool?
    let pendingIntentId: String?
    let questions: [String]?
    let dialogId: String?
    let result: [String: JSONValue]?
    var confirmationType: String? = nil
    var parsedAction: JSONValue? = nil
    var cards: [ConversationCard]? = nil
}

struct CreateDialogRequest: Codable { let title: String }

struct AgentDialogSummary: Codable {
    let dialogId: String
    let userId: String?
    let title: String?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateDialogMessageRequest: Codable {
    let role: String
    let content: String
    var transcript: String? = nil
    var result: String? = nil
}

struct TextActionRequest: Codable {
    let text: String
    var execute: Bool = true
    var dialogId: String? = nil
    var pendingIntentId: String? = nil
}

struct ConversationCard: Codable, Identifiable {
    var id: String? = nil
    var version: Int = 1
    var type: String? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var status: String? = nil
    var pendingIntentId: String? = nil
    var fields: [ConversationField]? = nil
    var actions: [ConversationAction]? = nil
    var item: [String: JSONValue]? = nil
    var items: [[String: JSONValue]]? = nil
}

struct ConversationField: Codable {
    var label: String? = nil
    var value: String? = nil
    var format: String? = nil
}

struct ConversationAction: Codable {
    var kind: String? = nil
    var label: String? = nil
    var value: String? = nil
}

struct ConfirmIntentRequest: Codable {
    let pendingIntentId: String
    var answers: [String: JSONValue] = [:]
}

// ── Valid Types ───────────────────────────────────────────────────
struct TaskLabel: Codable, Identifiable, Hashable {
    let labelId: String?
    let categoryId: String?
    let label: String
    let description: String?

    var id: String { labelId ?? label }
}

struct PriorityLevel: Codable, Identifiable, Hashable {
    let priorityLevelId: String
    let priorityLevel: Int
    let description: String?

    var id: String { priorityLevelId }
}

struct TaskStatus: Codable {
    let taskStatusId: String
    let taskStatus: String
    let description: String?
}

struct RecurrenceType: Codable {
    let repeatTypeId: String
    let recurrenceType: String
}

// ── Recurrence ────────────────────────────────────────────────────
struct RecurrenceEngineRunResponse: Codable {
    var ok: Bool? = nil
    var created: Int? = nil
    var tasks: [String]? = nil
    var message: String? = nil
}

struct RecurrenceRule: Codable {
    let recurrenceRuleId: String
    let parentTaskId: String?
    let sourceTaskId: String?
    let repeatTypeId: String
    let repeatEvery: Int?
    let endDate: String?
    let occurrenceCount: Int?
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
}

struct OkResponse: Codable { var ok: Bool? = nil }

struct DeleteRepeatedTasksRequest: Codable {
    var taskIds: [String]? = nil
    var fromDatetime: String? = nil
    var toDatetime: String? = nil
}

struct RepeatedTaskChanges: Codable {
    var title: String? = nil
    var name: String? = nil
    var description: String? = nil
    var labelId: String? = nil
    var priorityLevelId: String? = nil
    var startDatetime: String? = nil
    var endDatetime: String? = nil
    var location: String? = nil
}

struct UpdateRepeatedTasksRequest: Codable {
    let changes: RepeatedTaskChanges
    var taskIds: [String]? = nil
    var fromDatetime: String? = nil
    var toDatetime: String? = nil
}

struct RecurrenceSpec: Codable {
    let repeatTypeId: String
    var repeatEvery: Int = 1
    let timeOfDay: String
    let timezone: String
    var isActive: Bool = true
}

struct RecurrencePatternItem: Codable {
    var weekdayId: String? = nil
}

struct CreateTaskWithRecurrenceRequest: Codable {
    let title: String
    var description: String? = nil
    var labelId: String? = nil
    var priorityLevelId: String? = nil
    let startDatetime: String
    let endDatetime: String
    var location: String? = nil
    var subjectUserId: String? = nil
    var familyAccountId: String? = nil
    let recurrence: RecurrenceSpec
    var recurrencePatterns: [RecurrencePatternItem]? = nil
    var lookaheadDays: Int = 30
}

/// POST /api/v1/tasks/with-recurrence returns a wrapper, not a bare task.
struct CreateTaskWithRecurrenceResponse: Codable {
    var ok: Bool? = nil
    let task: TaskItem
    var recurrenceRule: RecurrenceRule? = nil
    var generatedCount: Int? = nil
    var generatedTasks: [TaskItem]? = nil
}

// ── My Day Response ───────────────────────────────────────────────
struct MyDayGroup: Codable {
    let tasks: [TaskItem]
    let labelId: String?
    let labelName: String?
    let labelPriority: Int?
}

struct MyDayResponse: Codable {
    let date: String?
    let greeting: String?
    let groups: [MyDayGroup]?
    let seniorUserId: String?
}

// ── Weekly Summary / Reports ──────────────────────────────────────
struct WeeklySummaryResponse: Codable {
    let seniorUserId: String?
    let weekStart: String?
    let weekEnd: String?
    let weeklySummary: WeeklySummaryStatsResponse?
    let medicationAdherence: MedicationAdherenceResponse?
    let dailyRoutineStability: DailyRoutineStabilityResponse?
    let appointmentSchedule: AppointmentReliabilityResponse?
    let caregiverActivity: CaregiverActivityResponse?
    let alertsEscalationHistory: [EscalationResponse]?
    let aiSummaryText: String?
    let aiRoutineNote: String?
}

struct WeeklySummaryStatsResponse: Codable {
    let medicationAdherencePct: Int?
    let criticalMissedTasksCount: Int?
    let appointmentsKept: Int?
    let appointmentsTotal: Int?
    let caregiverVisitsCompleted: Int?
}

struct MedicationAdherenceResponse: Codable {
    let prescribedMedications: [String]?
    let takenOnTimePct: Int?
    let takenLatePct: Int?
    let missedPct: Int?
    let escalationsTriggered: Int?
    let insightBadge: String?
}

struct DailyRoutineStabilityResponse: Codable {
    let indicators: [RoutineIndicatorResponse]?
}

struct RoutineIndicatorResponse: Codable {
    let name: String?
    let status: String?
}

struct AppointmentReliabilityResponse: Codable {
    let scheduled: Int?
    let attended: Int?
    let late: Int?
    let missed: Int?
}

struct CaregiverActivityResponse: Codable {
    let visitsScheduled: Int?
    let visitsCompleted: Int?
    let tasksCompleted: Int?
    let notesSubmitted: Int?
    let issuesFlagged: Int?
}

struct EscalationResponse: Codable {
    let date: String?
    let task: String?
    let level: Int?
    let action: String?
}

// ── Task Assignment Offers ────────────────────────────────────────
struct TaskAssignmentOfferRequest: Codable {
    let taskId: String
    let toUserId: String
    var message: String? = nil
    var expiresInMinutes: Int = 60
    var proposedStart: String? = nil
    var proposedEnd: String? = nil
}

struct TaskAssignmentRequest: Codable {
    let taskId: String
    let userId: String
    var taskRoleId: String? = nil
}

struct TaskAssignmentOffer: Codable, Identifiable {
    let offerId: String
    let taskId: String
    let fromUserId: String?
    let toUserId: String?
    let status: String?
    let message: String?
    let proposedStart: String?
    let proposedEnd: String?
    let expiresAt: String?
    let familyAccountId: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { offerId }
}

struct TaskAssignmentCandidate: Codable, Identifiable, Hashable {
    let userId: String?
    let displayName: String?
    let role: String?
    let hasConflict: Bool?
    let conflictDetail: String?
    let offerStatus: String?

    var id: String { userId ?? displayName ?? UUID().uuidString }
}

struct SeniorInfo: Codable {
    let userId: String?
    let familyAccountId: String?
    let name: String?
    let email: String?
}

struct RegisterDeviceRequest: Codable {
    let token: String
    var platform: String = "ios"
}

struct DeviceResponse: Codable {
    let deviceId: String?
    let token: String?
    let platform: String?
    let deviceName: String?
    let createdAt: String?
}

// ── User Settings: Time Zone ──────────────────────────────────────
struct TimeZoneResponse: Codable { let timeZone: String }
struct UpdateTimeZoneRequest: Codable { let timeZone: String }
struct ConvertTimeZoneRequest: Codable {
    let utcDatetime: String
    var timeZone: String? = nil
}
struct ConvertTimeZoneResponse: Codable {
    let localDatetime: String
    let timeZone: String
}

// ── User Notification Policy ──────────────────────────────────────
struct NotificationPolicy: Codable, Identifiable {
    let notificationPolicyId: String?
    let priorityLevelId: String?
    let taskRoleId: String?
    var enabled: Bool?
    var repeatIntervalSeconds: Int?
    var maxRepeats: Int?
    var requiresAcknowledgement: Bool?
    var requiresConfirmation: Bool?
    var requiresEscalation: Bool?
    var escalationAfterMinutes: Int?
    var overrideSilentMode: Bool?
    var escalateToUserIds: [String]?
    var escalateToEmergencyContactIds: [String]? = nil
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var id: String { notificationPolicyId ?? priorityLevelId ?? UUID().uuidString }
}

struct CreateNotificationPolicyRequest: Codable {
    var priorityLevelId: String? = nil
    var taskRoleId: String? = nil
    var enabled: Bool = true
    var repeatIntervalSeconds: Int = 0
    var maxRepeats: Int = 0
    var requiresAcknowledgement: Bool = false
    var requiresConfirmation: Bool = false
    var requiresEscalation: Bool = false
    var escalationAfterMinutes: Int = 0
    var overrideSilentMode: Bool = false
    var escalateToUserIds: [String] = []
    var escalateToEmergencyContactIds: [String] = []
}

struct UpdateNotificationPolicyRequest: Codable {
    var enabled: Bool = true
    var repeatIntervalSeconds: Int = 0
    var maxRepeats: Int = 0
    var requiresAcknowledgement: Bool = false
    var requiresConfirmation: Bool = false
    var requiresEscalation: Bool = false
    var escalationAfterMinutes: Int = 0
    var overrideSilentMode: Bool = false
    var escalateToUserIds: [String] = []
    var escalateToEmergencyContactIds: [String] = []
}

// ── Program Settings ──────────────────────────────────────────────
struct ProgramSettings: Codable {
    var accountSecurity: AccountSecurity? = nil
    var notificationsAlerts: JSONValue? = nil
    var taskPreferences: TaskPreferences? = nil
    var accessibilityUx: AccessibilityUx? = nil
    var languagePreference: String? = nil
    var _id: String? = nil
    var userId: String? = nil
    var familyAccountId: String? = nil
}

struct TaskPreferences: Codable {
    var taskPrioritizationEnabled: Bool? = nil
    var dueSoonThresholdHours: Int? = nil
    var completionCheckFrequencyMinutes: Int? = nil
}

struct AccessibilityUx: Codable {
    var fontSize: String? = nil
    var interfaceMode: String? = nil
    var highContrastMode: Bool? = nil
    var screenReaderEnabled: Bool? = nil
    var voiceGuidedNavigation: Bool? = nil
    var textToSpeech: Bool? = nil
    var speechSpeed: String? = nil
    var speechVolume: Int? = nil
}

struct AccountSecurity: Codable {
    var biometricLogin: Bool? = nil
    var autoLogoutMinutes: Int? = nil
    var dataSharingConsent: DataSharingConsent? = nil
    var legal: LegalInfo? = nil
}

struct DataSharingConsent: Codable {
    var healthData: Bool? = nil
    var taskActivity: Bool? = nil
    var notificationActivity: Bool? = nil
    var productAnalytics: Bool? = nil
    var thirdPartyServices: Bool? = nil
}

struct LegalInfo: Codable {
    var termsOfUseAccepted: Bool? = nil
    var termsOfUseVersion: String? = nil
    var informedConsentAccepted: Bool? = nil
    var informedConsentVersion: String? = nil
    var localLegalNoticeAcknowledged: Bool? = nil
    var localLegalNoticeVersion: String? = nil
}

// ── Family Account ────────────────────────────────────────────────
struct FamilyAccountInfo: Codable {
    let familyAccountId: String?
    let name: String?
    let createdAt: String?
    let updatedAt: String?
}

struct FamilyMember: Codable, Identifiable {
    let userId: String?
    let familyAccountId: String?
    let name: String?
    let username: String?
    let email: String?
    let roleId: String?
    let status: String?
    let createdAt: String?
    let updatedAt: String?
    var permissions: LinkedPermissions? = nil
    var canManage: Bool? = nil

    var id: String { userId ?? username ?? email ?? UUID().uuidString }
}

struct FamilyDetailResponse: Codable {
    let family: FamilyAccountInfo?
    let members: [FamilyMember]?
}

struct LinkedPermissions: Codable {
    var viewSchedule: Bool = false
    var createReminders: Bool = false
    var editReminders: Bool = false
    var completeTasks: Bool = false
}

struct CreateInviteRequest: Codable {
    let role: String
    var email: String? = nil
    var phone: String? = nil
    var permissions: LinkedPermissions = LinkedPermissions()
}
struct MemberRoleRequest: Codable { let role: String }

struct InviteResponse: Codable {
    let token: String?
    let familyAccountId: String?
    let expiresAt: String?
    let expiresInMinutes: Int?
}

struct AcceptInviteRequest: Codable { let token: String }

struct AcceptInviteResponse: Codable {
    var message: String? = nil
    var familyAccountId: String? = nil
    var userId: String? = nil
    var role: String? = nil
    var roleId: String? = nil
}

struct LinkedChangeRequest: Codable {
    var kind: String = "task"
    var action: String = "update"
    var targetId: String? = nil
    var ownerUserId: String? = nil
    var changes: [String: String] = [:]
    let reason: String
}

struct LinkedChange: Codable, Identifiable {
    let requestId: String
    let title: String?
    let kind: String
    let action: String
    let changes: [String: JSONValue]?
    let reason: String
    let status: String
    let canReview: Bool
    var id: String { requestId }
}

// ── Report view models (ported from FamilyReportScreen.kt data classes) ──
struct WeeklySummaryData {
    let seniorUserId: String?
    let weekStart: String?
    let weekEnd: String?
    let weeklySummary: WeeklySummaryStats?
    let medicationAdherence: MedicationAdherenceData?
    let dailyRoutineStability: DailyRoutineStability?
    let appointmentReliability: AppointmentReliability?
    let escalations: [EscalationItem]?
}

struct WeeklySummaryStats {
    let medicationAdherencePct: Int?
    let criticalMissedTasksCount: Int?
    let appointmentsKept: Int?
    let appointmentsTotal: Int?
    let caregiverVisitsCompleted: Int?
}

struct MedicationAdherenceData {
    let prescribedMedications: [String]?
    let takenOnTimePct: Int?
    let takenLatePct: Int?
    let missedPct: Int?
    let escalationsTriggered: Int?
    let insightBadge: String?
}

struct DailyRoutineStability {
    let indicators: [RoutineIndicator]?
}

struct RoutineIndicator: Identifiable {
    let name: String?
    let status: String?
    var id: String { (name ?? "") + (status ?? "") }
}

struct AppointmentReliability {
    let scheduled: Int?
    let attended: Int?
    let late: Int?
    let missed: Int?
}

struct EscalationItem: Identifiable {
    let date: String?
    let task: String?
    let level: Int?
    let action: String?
    var id: String { (date ?? "") + (task ?? "") + String(level ?? 0) }
}

// ── Small string helpers used across the port ─────────────────────
extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isNotBlank: Bool { !isBlank }

    /// Kotlin's `replaceFirstChar { it.uppercase() }`
    var capitalizedFirst: String {
        guard let f = first else { return self }
        return String(f).uppercased() + dropFirst()
    }

    /// Kotlin's `String.containsAny(vararg keywords)` — case-insensitive.
    func containsAny(_ keywords: String...) -> Bool {
        let lower = lowercased()
        return keywords.contains { lower.contains($0.lowercased()) }
    }

    func padStart(_ length: Int, _ pad: Character) -> String {
        count >= length ? self : String(repeating: String(pad), count: length - count) + self
    }

    var digitsOnly: String { filter { $0.isNumber } }

    /// Kotlin's `take(n)`
    func take(_ n: Int) -> String { String(prefix(n)) }
}

extension Optional where Wrapped == String {
    var isNullOrBlank: Bool {
        guard let s = self else { return true }
        return s.isBlank
    }
    var isNullOrEmpty: Bool {
        guard let s = self else { return true }
        return s.isEmpty
    }
}
