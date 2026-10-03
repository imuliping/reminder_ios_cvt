//
//  APIService.swift
//  Port of the Retrofit `ApiService` interface + `RetrofitClient` in
//  shared/Network.kt, rebuilt on URLSession + async/await.
//
//  Behaviour kept from the Android client:
//   • Bearer token injected from TokenManager on every request
//   • every request/response logged through LogManager
//   • 30s connect/read/write timeouts
//   • null fields omitted from request bodies (Gson's default, and also
//     JSONEncoder's behaviour for nil Optionals)
//

import Foundation

enum APIError: LocalizedError {
    case badURL
    case http(code: Int, detail: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badURL:                   return "Invalid request URL"
        case .http(let code, let d):    return d.isEmpty ? "HTTP \(code)" : d
        case .decoding(let d):          return "Could not read the server response: \(d)"
        case .transport(let d):         return d
        }
    }
}

/// Mirrors Retrofit's `@Query` semantics: nil values are dropped.
typealias Query = [(String, Any?)]

final class APIService {

    static let shared = APIService()

    /// Same host as RetrofitClient.baseUrl in the Android app.
    static let baseURLString = "http://karyg.geofb.com:6682/"

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    // ── Request plumbing ──────────────────────────────────────────

    private func url(_ path: String, _ query: Query = []) throws -> URL {
        guard var comps = URLComponents(string: APIService.baseURLString + path) else {
            throw APIError.badURL
        }
        let items: [URLQueryItem] = query.compactMap { key, value in
            guard let value else { return nil }
            if let b = value as? Bool { return URLQueryItem(name: key, value: b ? "true" : "false") }
            return URLQueryItem(name: key, value: String(describing: value))
        }
        if !items.isEmpty { comps.queryItems = items }
        guard let u = comps.url else { throw APIError.badURL }
        return u
    }

    private func authorized(_ request: inout URLRequest) {
        if let token = TokenManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Replaces the `logManagerInterceptor` + error-detail regex from Network.kt.
    private func perform(_ request: URLRequest) async throws -> Data {
        let urlString = request.url?.absoluteString ?? ""
        LogManager.logHttp("--> \(request.httpMethod ?? "GET")", urlString)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            LogManager.logError("HTTP FAILED \(request.httpMethod ?? "") \(urlString)", error)
            throw APIError.transport(error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code >= 400 {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            let detail = Self.extractDetail(bodyString)
            LogManager.logHttpError(code, urlString, detail)
            throw APIError.http(code: code, detail: detail)
        }
        LogManager.logHttpResponse(code, urlString)
        return data
    }

    private static func extractDetail(_ body: String) -> String {
        if let range = body.range(of: #""detail"\s*:\s*"([^"]+)""#, options: .regularExpression) {
            let match = String(body[range])
            if let q = match.range(of: #":\s*""#, options: .regularExpression) {
                return String(match[q.upperBound...].dropLast())
            }
        }
        return body.take(100)
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        if T.self == String.self {
            // Several endpoints return a bare JSON string (or sometimes plain text).
            if let s = try? decoder.decode(String.self, from: data) { return s as! T }
            return (String(data: data, encoding: .utf8) ?? "") as! T
        }
        if data.isEmpty, let empty = EmptyBody() as? T { return empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            LogManager.logError("decode \(T.self) failed: \(error)")
            throw APIError.decoding(String(describing: error))
        }
    }

    // ── Verbs ─────────────────────────────────────────────────────

    func get<T: Decodable>(_ path: String, _ query: Query = [], as type: T.Type) async throws -> T {
        var req = URLRequest(url: try url(path, query))
        req.httpMethod = "GET"
        authorized(&req)
        return try decode(try await perform(req), as: type)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil, query: Query = [], as type: T.Type) async throws -> T {
        var req = URLRequest(url: try url(path, query))
        req.httpMethod = "POST"
        authorized(&req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(AnyEncodable(body))
        } else {
            // FastAPI endpoints with an optional body still expect valid JSON.
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data("{}".utf8)
        }
        return try decode(try await perform(req), as: type)
    }

    func put<T: Decodable>(_ path: String, body: Encodable, query: Query = [], as type: T.Type) async throws -> T {
        var req = URLRequest(url: try url(path, query))
        req.httpMethod = "PUT"
        authorized(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(AnyEncodable(body))
        return try decode(try await perform(req), as: type)
    }

    func delete<T: Decodable>(_ path: String, body: Encodable? = nil, query: Query = [], as type: T.Type) async throws -> T {
        var req = URLRequest(url: try url(path, query))
        req.httpMethod = "DELETE"
        authorized(&req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return try decode(try await perform(req), as: type)
    }

    /// Retrofit's `@FormUrlEncoded` — only the login endpoint uses it.
    func postForm<T: Decodable>(_ path: String, fields: [String: String], as type: T.Type) async throws -> T {
        var req = URLRequest(url: try url(path))
        req.httpMethod = "POST"
        authorized(&req)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = fields.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        req.httpBody = Data(encoded.utf8)
        return try decode(try await perform(req), as: type)
    }

    /// Retrofit's `@Multipart` — used for the agent voice endpoints.
    func postMultipart<T: Decodable>(
        _ path: String,
        fileField: String,
        fileURL: URL,
        fileMimeType: String,
        fields: [String: String],
        as type: T.Type
    ) async throws -> T {
        var req = URLRequest(url: try url(path))
        req.httpMethod = "POST"
        authorized(&req)
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        for (key, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        let fileData = try Data(contentsOf: fileURL)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: \(fileMimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        req.httpBody = body
        return try decode(try await perform(req), as: type)
    }
}

/// Stands in for Retrofit's `Any` / `Unit` return types.
struct EmptyBody: Codable {}

/// Lets `Encodable` existentials be encoded (Swift can't do that directly).
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeClosure = { encoder in try wrapped.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

// ─────────────────────────────────────────────────────────────────
//  The endpoint surface — one function per Retrofit method,
//  same paths, same query/body shapes.
// ─────────────────────────────────────────────────────────────────

extension APIService {

    // ── Linked changes ────────────────────────────────────────────
    func getLinkedChanges() async throws -> [LinkedChange] {
        try await get("api/v1/linked-changes", as: [LinkedChange].self)
    }

    func proposeLinkedChange(_ request: LinkedChangeRequest) async throws -> LinkedChange {
        try await post("api/v1/linked-changes", body: request, as: LinkedChange.self)
    }

    func approveLinkedChange(_ id: String) async throws -> EmptyBody {
        try await post("api/v1/linked-changes/\(id)/approve", as: EmptyBody.self)
    }

    func rejectLinkedChange(_ id: String) async throws -> EmptyBody {
        try await post("api/v1/linked-changes/\(id)/reject", as: EmptyBody.self)
    }

    // ── Auth ──────────────────────────────────────────────────────
    func login(username: String, password: String) async throws -> LoginResponse {
        try await postForm("api/v1/auth/login",
                           fields: ["username": username, "password": password],
                           as: LoginResponse.self)
    }

    func signup(_ request: SignupRequest) async throws -> LoginResponse {
        try await post("api/v1/auth/signup", body: request, as: LoginResponse.self)
    }

    func getMe() async throws -> Me {
        try await get("api/v1/auth/me", as: Me.self)
    }

    func getSessionSettings() async throws -> SessionSettings {
        try await get("api/v1/auth/session", as: SessionSettings.self)
    }

    func setSessionSettings(_ settings: SessionSettings) async throws -> SessionSettings {
        try await put("api/v1/auth/session", body: settings, as: SessionSettings.self)
    }

    func recordSessionActivity() async throws -> EmptyBody {
        try await post("api/v1/auth/session/activity", as: EmptyBody.self)
    }

    func revokeSession() async throws -> EmptyBody {
        try await post("api/v1/auth/logout", as: EmptyBody.self)
    }

    // ── Forgot Password ───────────────────────────────────────────
    func forgotPasswordRequest(_ r: ForgotPasswordRequest) async throws -> ForgotPasswordRequestResponse {
        try await post("api/v1/auth/forgot-password/request", body: r, as: ForgotPasswordRequestResponse.self)
    }

    func forgotPasswordVerify(_ r: ForgotPasswordVerifyRequest) async throws -> ForgotPasswordVerifyResponse {
        try await post("api/v1/auth/forgot-password/verify", body: r, as: ForgotPasswordVerifyResponse.self)
    }

    func forgotPasswordReset(_ r: ForgotPasswordResetRequest) async throws -> String {
        try await post("api/v1/auth/forgot-password/reset", body: r, as: String.self)
    }

    // ── Users ─────────────────────────────────────────────────────
    func getUser(_ userId: String) async throws -> User {
        try await get("api/v1/users/\(userId)", as: User.self)
    }

    func updateUser(_ userId: String, _ r: UpdateUserRequest) async throws -> User {
        try await put("api/v1/users/\(userId)", body: r, as: User.self)
    }

    // ── Parent Tasks ──────────────────────────────────────────────
    func getParentTasks() async throws -> [ParentTask] {
        try await get("api/v1/parent-tasks", as: [ParentTask].self)
    }

    func getParentTask(_ parentTaskId: String) async throws -> ParentTask {
        try await get("api/v1/parent-tasks/\(parentTaskId)", as: ParentTask.self)
    }

    // ── Tasks ─────────────────────────────────────────────────────
    func getTasks(date: String? = nil, subjectUserId: String? = nil, userId: String? = nil,
                  includeShopping: Bool? = nil, fromDt: String? = nil, toDt: String? = nil) async throws -> [TaskItem] {
        try await get("api/v1/tasks", [
            ("date", date), ("subjectUserId", subjectUserId), ("userId", userId),
            ("includeShopping", includeShopping), ("from_dt", fromDt), ("to_dt", toDt)
        ], as: [TaskItem].self)
    }

    func getShoppingList(subjectUserId: String? = nil, assignedTo: String? = nil,
                         includeShopping: Bool = true, limit: Int = 100) async throws -> [TaskItem] {
        try await get("api/v1/tasks/shopping-list", [
            ("subjectUserId", subjectUserId), ("assigned_to", assignedTo),
            ("includeShopping", includeShopping), ("limit", limit)
        ], as: [TaskItem].self)
    }

    func getUpcomingScheduleTasks(subjectUserId: String? = nil, userId: String? = nil,
                                  assignedTo: String? = nil, createdBy: String? = nil,
                                  toDt: String? = nil, includeShopping: Bool = false) async throws -> [TaskItem] {
        try await get("api/v1/tasks/schedule/upcoming", [
            ("subjectUserId", subjectUserId), ("userId", userId), ("assigned_to", assignedTo),
            ("created_by", createdBy), ("toDt", toDt), ("includeShopping", includeShopping)
        ], as: [TaskItem].self)
    }

    func getUpcomingTodoListTasks(subjectUserId: String? = nil, userId: String? = nil,
                                  assignedTo: String? = nil, createdBy: String? = nil,
                                  toDt: String? = nil, includeShopping: Bool = false) async throws -> [TaskItem] {
        try await get("api/v1/tasks/todo-list/upcoming", [
            ("subjectUserId", subjectUserId), ("userId", userId), ("assigned_to", assignedTo),
            ("created_by", createdBy), ("toDt", toDt), ("includeShopping", includeShopping)
        ], as: [TaskItem].self)
    }

    func getScheduleTasks(subjectUserId: String? = nil, userId: String? = nil,
                          assignedTo: String? = nil, createdBy: String? = nil,
                          fromDt: String? = nil, toDt: String? = nil,
                          limit: Int = 100, offset: Int = 0,
                          includeShopping: Bool = false) async throws -> [TaskItem] {
        try await get("api/v1/tasks/schedule", [
            ("subjectUserId", subjectUserId), ("userId", userId), ("assigned_to", assignedTo),
            ("created_by", createdBy), ("from_dt", fromDt), ("to_dt", toDt),
            ("limit", limit), ("offset", offset), ("includeShopping", includeShopping)
        ], as: [TaskItem].self)
    }

    func getTodoListTasks(subjectUserId: String? = nil, includeShopping: Bool = false,
                          limit: Int = 100, offset: Int = 0,
                          fromDt: String? = nil, toDt: String? = nil,
                          assignedTo: String? = nil, createdBy: String? = nil) async throws -> [TaskItem] {
        try await get("api/v1/tasks/todo-list", [
            ("subjectUserId", subjectUserId), ("includeShopping", includeShopping),
            ("limit", limit), ("offset", offset), ("from_dt", fromDt), ("to_dt", toDt),
            ("assigned_to", assignedTo), ("created_by", createdBy)
        ], as: [TaskItem].self)
    }

    /// GET /api/v1/tasks/family — tasks where the authenticated user is a participant.
    func getMyFamilyTasks() async throws -> [TaskItem] {
        try await get("api/v1/tasks/family", as: [TaskItem].self)
    }

    func createTaskAssignment(_ r: TaskAssignmentRequest) async throws -> EmptyBody {
        try await post("api/v1/task-assignments", body: r, as: EmptyBody.self)
    }

    func createTask(_ r: TaskRequest) async throws -> TaskItem {
        try await post("api/v1/tasks", body: r, as: TaskItem.self)
    }

    func updateTask(_ taskId: String, _ r: TaskRequest) async throws -> TaskItem {
        try await put("api/v1/tasks/\(taskId)", body: r, as: TaskItem.self)
    }

    func getTask(_ taskId: String) async throws -> TaskItem {
        try await get("api/v1/tasks/\(taskId)", as: TaskItem.self)
    }

    func deleteTask(_ taskId: String) async throws -> OkResponse {
        try await delete("api/v1/tasks/\(taskId)", as: OkResponse.self)
    }

    func startTask(_ taskId: String) async throws -> TaskItem {
        try await post("api/v1/tasks/\(taskId)/start", as: TaskItem.self)
    }

    func completeTask(_ taskId: String, _ r: CompleteTaskRequest) async throws -> TaskStatusResponse {
        try await post("api/v1/tasks/\(taskId)/complete", body: r, as: TaskStatusResponse.self)
    }

    func skipTask(_ taskId: String, _ r: CompleteTaskRequest = CompleteTaskRequest()) async throws -> TaskStatusResponse {
        try await post("api/v1/tasks/\(taskId)/skip", body: r, as: TaskStatusResponse.self)
    }

    func createTaskWithRecurrence(_ r: CreateTaskWithRecurrenceRequest) async throws -> CreateTaskWithRecurrenceResponse {
        try await post("api/v1/tasks/with-recurrence", body: r, as: CreateTaskWithRecurrenceResponse.self)
    }

    func updateTaskWithRecurrence(_ taskId: String, _ r: CreateTaskWithRecurrenceRequest) async throws -> TaskItem {
        try await put("api/v1/tasks/\(taskId)/with-recurrence", body: r, as: TaskItem.self)
    }

    func updateRepeatedTasks(_ taskId: String, _ r: UpdateRepeatedTasksRequest) async throws -> String {
        try await put("api/v1/tasks/\(taskId)/repeated-tasks", body: r, as: String.self)
    }

    /// DELETE with a body — Retrofit needed @HTTP(hasBody = true) for this one.
    func deleteRepeatedTasks(_ taskId: String, _ r: DeleteRepeatedTasksRequest) async throws {
        _ = try await delete("api/v1/tasks/\(taskId)/repeated-tasks", body: r, as: EmptyBody.self)
    }

    func deleteShoppingItem(_ itemId: String) async throws -> String {
        try await delete("api/v1/shopping-items/\(itemId)", as: String.self)
    }

    // ── Recurrence ────────────────────────────────────────────────
    func getRecurrenceRules(sourceTaskId: String? = nil, activeOnly: Bool? = nil) async throws -> [RecurrenceRule] {
        try await get("api/v1/recurrence-rules",
                      [("sourceTaskId", sourceTaskId), ("active_only", activeOnly)],
                      as: [RecurrenceRule].self)
    }

    // ── Notifications ─────────────────────────────────────────────
    func getNotificationInbox() async throws -> [NotificationInboxItem] {
        try await get("api/v1/notification/inbox", as: [NotificationInboxItem].self)
    }

    func getNotification(_ notificationId: String) async throws -> NotificationDetailResponse {
        try await get("api/v1/notification/\(notificationId)", as: NotificationDetailResponse.self)
    }

    func completeNotification(_ notificationId: String,
                              _ r: NotificationActionRequest = NotificationActionRequest()) async throws -> NotificationInboxItem {
        try await post("api/v1/notification/\(notificationId)/action", body: r, as: NotificationInboxItem.self)
    }

    func getNotificationFeed() async throws -> [NotificationFeedItem] {
        try await get("api/v1/notification/feed", as: [NotificationFeedItem].self)
    }

    func acknowledgeNotification(_ notificationId: String,
                                 _ r: AckNotificationRequest = AckNotificationRequest()) async throws -> NotificationInboxItem {
        try await post("api/v1/notification/\(notificationId)/ack", body: r, as: NotificationInboxItem.self)
    }

    func dismissNotification(_ notificationId: String, _ r: DismissNotificationRequest) async throws -> EmptyBody {
        try await post("api/v1/notification/\(notificationId)/dismiss", body: r, as: EmptyBody.self)
    }

    func snoozeNotification(_ notificationId: String, _ r: SnoozeNotificationRequest) async throws -> EmptyBody {
        try await post("api/v1/notification/\(notificationId)/snooze", body: r, as: EmptyBody.self)
    }

    // ── Emergency Contacts ────────────────────────────────────────
    func getEmergencyContacts(seniorUserId: String? = nil) async throws -> [EmergencyContact] {
        try await get("api/v1/emergency-contacts", [("seniorUserId", seniorUserId)], as: [EmergencyContact].self)
    }

    func createEmergencyContact(_ r: CreateEmergencyContactRequest) async throws -> EmergencyContact {
        try await post("api/v1/emergency-contacts", body: r, as: EmergencyContact.self)
    }

    func updateEmergencyContact(_ id: String, _ r: UpdateEmergencyContactRequest) async throws -> EmergencyContact {
        try await put("api/v1/emergency-contacts/\(id)", body: r, as: EmergencyContact.self)
    }

    func deleteEmergencyContact(_ id: String) async throws -> String {
        try await delete("api/v1/emergency-contacts/\(id)", as: String.self)
    }

    // ── Team Chat ─────────────────────────────────────────────────
    func getTeamChatMessages(seniorUserId: String? = nil, familyAccountId: String? = nil,
                             before: String? = nil, limit: Int = 50) async throws -> [TeamChatMessage] {
        try await get("api/v1/team-chat/messages", [
            ("seniorUserId", seniorUserId), ("familyAccountId", familyAccountId),
            ("before", before), ("limit", limit)
        ], as: [TeamChatMessage].self)
    }

    func sendTeamChatMessage(_ r: SendTeamChatMessageRequest) async throws -> TeamChatMessage {
        try await post("api/v1/team-chat/messages", body: r, as: TeamChatMessage.self)
    }

    // ── Alarms ────────────────────────────────────────────────────
    func getActiveAlarms() async throws -> [Alarm] {
        try await get("api/v1/alarms/active", as: [Alarm].self)
    }

    // ── Agent ─────────────────────────────────────────────────────
    func getAgentDialog(_ dialogId: String) async throws -> AgentDialog {
        try await get("api/v1/agent-dialogs/\(dialogId)", as: AgentDialog.self)
    }

    func createAgentDialog(_ r: CreateDialogRequest) async throws -> AgentDialogSummary {
        try await post("api/v1/agent-dialogs", body: r, as: AgentDialogSummary.self)
    }

    func listAgentDialogs() async throws -> [AgentDialogSummary] {
        try await get("api/v1/agent-dialogs", as: [AgentDialogSummary].self)
    }

    func listDialogMessages(_ dialogId: String, limit: Int = 200) async throws -> [AgentDialogMessage] {
        try await get("api/v1/agent-dialogs/\(dialogId)/messages", [("limit", limit)],
                      as: [AgentDialogMessage].self)
    }

    func createDialogMessage(_ dialogId: String, _ r: CreateDialogMessageRequest) async throws -> String {
        try await post("api/v1/agent-dialogs/\(dialogId)/messages", body: r, as: String.self)
    }

    func sendTextAction(_ r: TextActionRequest) async throws -> TextActionResponse {
        try await post("api/v1/agent/text-action", body: r, as: TextActionResponse.self)
    }

    func sendVoiceAction(audio: URL, execute: String, dialogId: String?, language: String?) async throws -> TextActionResponse {
        var fields = ["execute": execute]
        if let dialogId { fields["dialog_id"] = dialogId }
        if let language { fields["language"] = language }
        return try await postMultipart("api/v1/agent/voice-action",
                                       fileField: "audio", fileURL: audio,
                                       fileMimeType: "audio/mp4",
                                       fields: fields, as: TextActionResponse.self)
    }

    func sendDialogVoiceAction(_ dialogId: String, audio: URL, execute: String, language: String?) async throws -> TextActionResponse {
        var fields = ["execute": execute]
        if let language { fields["language"] = language }
        return try await postMultipart("api/v1/agent-dialogs/\(dialogId)/voice-action",
                                       fileField: "audio", fileURL: audio,
                                       fileMimeType: "audio/mp4",
                                       fields: fields, as: TextActionResponse.self)
    }

    func confirmIntent(_ r: ConfirmIntentRequest) async throws -> TextActionResponse {
        try await post("api/v1/agent/confirm", body: r, as: TextActionResponse.self)
    }

    // ── Valid Types ───────────────────────────────────────────────
    func getLabels() async throws -> [TaskLabel] {
        try await get("api/v1/valid-types/labels", as: [TaskLabel].self)
    }

    func getPriorityLevels() async throws -> [PriorityLevel] {
        try await get("api/v1/valid-types/priority-levels", as: [PriorityLevel].self)
    }

    func getTaskStatuses() async throws -> [TaskStatus] {
        try await get("api/v1/valid-types/task-statuses", as: [TaskStatus].self)
    }

    func getRecurrenceTypes() async throws -> [RecurrenceType] {
        try await get("api/v1/valid-types/recurrence-types", as: [RecurrenceType].self)
    }

    // ── My Day ────────────────────────────────────────────────────
    func getMyDay(date: String? = nil, seniorId: String? = nil, timezone: String? = nil) async throws -> MyDayResponse {
        try await get("api/v1/my-day",
                      [("date", date), ("seniorId", seniorId), ("timezone", timezone)],
                      as: MyDayResponse.self)
    }

    // ── Reports ───────────────────────────────────────────────────
    func getWeeklySummary(seniorUserId: String? = nil, weekStart: String? = nil) async throws -> WeeklySummaryResponse {
        try await get("api/v1/reports/weekly-summary",
                      [("seniorUserId", seniorUserId), ("week_start", weekStart)],
                      as: WeeklySummaryResponse.self)
    }

    func getEscalations(limit: Int = 100) async throws -> [EscalationResponse] {
        try await get("api/v1/reports/escalations", [("limit", limit)], as: [EscalationResponse].self)
    }

    // ── Task Assignment Offers ────────────────────────────────────
    func getAssignmentCandidates(taskId: String? = nil, excludeDeclined: Bool = true) async throws -> [TaskAssignmentCandidate] {
        try await get("api/v1/task-assignment-offers/candidates",
                      [("task_id", taskId), ("exclude_declined", excludeDeclined)],
                      as: [TaskAssignmentCandidate].self)
    }

    func createAssignmentOffer(_ r: TaskAssignmentOfferRequest) async throws -> TaskAssignmentOffer {
        try await post("api/v1/task-assignment-offers", body: r, as: TaskAssignmentOffer.self)
    }

    func getMyOffers(status: String? = nil) async throws -> [TaskAssignmentOffer] {
        try await get("api/v1/task-assignment-offers", [("status", status)], as: [TaskAssignmentOffer].self)
    }

    func getOffersForTask(_ taskId: String, status: String? = nil) async throws -> [TaskAssignmentOffer] {
        try await get("api/v1/task-assignment-offers/task/\(taskId)", [("status", status)],
                      as: [TaskAssignmentOffer].self)
    }

    func acceptOffer(_ offerId: String, body: [String: String]) async throws -> TaskAssignmentOffer {
        try await post("api/v1/task-assignment-offers/\(offerId)/accept", body: body, as: TaskAssignmentOffer.self)
    }

    func declineOffer(_ offerId: String, body: [String: String]) async throws -> TaskAssignmentOffer {
        try await post("api/v1/task-assignment-offers/\(offerId)/decline", body: body, as: TaskAssignmentOffer.self)
    }

    func cancelOffer(_ offerId: String) async throws -> TaskAssignmentOffer {
        try await post("api/v1/task-assignment-offers/\(offerId)/cancel", as: TaskAssignmentOffer.self)
    }

    // ── Family Accounts ───────────────────────────────────────────
    func getMyFamilies() async throws -> [FamilyAccountInfo] {
        try await get("api/v1/family-accounts/me", as: [FamilyAccountInfo].self)
    }

    func getMySeniors() async throws -> [SeniorInfo] {
        try await get("api/v1/family-accounts/me/seniors", as: [SeniorInfo].self)
    }

    func getFamily(_ familyAccountId: String) async throws -> FamilyDetailResponse {
        try await get("api/v1/family-accounts/\(familyAccountId)", as: FamilyDetailResponse.self)
    }

    func removeFamilyMember(_ familyAccountId: String, _ userId: String) async throws -> EmptyBody {
        try await delete("api/v1/family-accounts/\(familyAccountId)/members/\(userId)", as: EmptyBody.self)
    }

    func createInvite(_ familyAccountId: String, _ r: CreateInviteRequest) async throws -> InviteResponse {
        try await post("api/v1/family-accounts/\(familyAccountId)/invite", body: r, as: InviteResponse.self)
    }

    func updateLinkedPermissions(_ familyId: String, _ userId: String,
                                 _ permissions: LinkedPermissions) async throws -> LinkedPermissions {
        try await put("api/v1/family-accounts/\(familyId)/members/\(userId)/permissions",
                      body: permissions, as: LinkedPermissions.self)
    }

    func updateLinkedRole(_ familyId: String, _ userId: String,
                          _ role: MemberRoleRequest) async throws -> EmptyBody {
        try await put("api/v1/family-accounts/\(familyId)/members/\(userId)/role",
                      body: role, as: EmptyBody.self)
    }

    func acceptInvite(_ r: AcceptInviteRequest) async throws -> AcceptInviteResponse {
        try await post("api/v1/family-accounts/invite/accept", body: r, as: AcceptInviteResponse.self)
    }

    // ── Notification Devices ──────────────────────────────────────
    func registerDevice(_ r: RegisterDeviceRequest) async throws -> DeviceResponse {
        try await post("api/v1/notification-devices", body: r, as: DeviceResponse.self)
    }

    func getMyDevices() async throws -> [DeviceResponse] {
        try await get("api/v1/notification-devices", as: [DeviceResponse].self)
    }

    func deleteDevice(_ deviceId: String) async throws -> EmptyBody {
        try await delete("api/v1/notification-devices/\(deviceId)", as: EmptyBody.self)
    }

    func sendTestPush(_ body: [String: String] = [:]) async throws -> String {
        try await post("api/v1/notification-devices/test-send", body: body, as: String.self)
    }

    // ── User Settings: Time Zone ──────────────────────────────────
    func getMyTimeZone() async throws -> TimeZoneResponse {
        try await get("api/v1/user-settings/time-zone", as: TimeZoneResponse.self)
    }

    func putMyTimeZone(_ r: UpdateTimeZoneRequest) async throws -> TimeZoneResponse {
        try await put("api/v1/user-settings/time-zone", body: r, as: TimeZoneResponse.self)
    }

    func convertUtcToLocal(_ r: ConvertTimeZoneRequest) async throws -> ConvertTimeZoneResponse {
        try await post("api/v1/user-settings/time-zone/convert", body: r, as: ConvertTimeZoneResponse.self)
    }

    // ── User Notification Policy ──────────────────────────────────
    func getMyNotificationPolicies(priorityLevelId: String? = nil, taskRoleId: String? = nil) async throws -> [NotificationPolicy] {
        try await get("api/v1/user-notification-policy",
                      [("priorityLevelId", priorityLevelId), ("taskRoleId", taskRoleId)],
                      as: [NotificationPolicy].self)
    }

    func createMyNotificationPolicy(_ r: CreateNotificationPolicyRequest) async throws -> NotificationPolicy {
        try await post("api/v1/user-notification-policy", body: r, as: NotificationPolicy.self)
    }

    func createCheckInRecipients(_ r: CheckInRecipientsRequest) async throws -> NotificationPolicy {
        try await post("api/v1/user-notification-policy", body: r, as: NotificationPolicy.self)
    }

    func updateCheckInRecipients(_ id: String, _ r: CheckInRecipientsRequest) async throws -> NotificationPolicy {
        try await put("api/v1/user-notification-policy/\(id)", body: r, as: NotificationPolicy.self)
    }

    func getMyNotificationPolicy(_ id: String) async throws -> NotificationPolicy {
        try await get("api/v1/user-notification-policy/\(id)", as: NotificationPolicy.self)
    }

    func updateMyNotificationPolicy(_ id: String, _ r: UpdateNotificationPolicyRequest) async throws -> NotificationPolicy {
        try await put("api/v1/user-notification-policy/\(id)", body: r, as: NotificationPolicy.self)
    }

    func deleteMyNotificationPolicy(_ id: String) async throws -> String {
        try await delete("api/v1/user-notification-policy/\(id)", as: String.self)
    }

    // ── Program Settings ──────────────────────────────────────────
    func getProgramSettings() async throws -> ProgramSettings {
        try await get("program-setting/", as: ProgramSettings.self)
    }

    func updateProgramSettings(_ r: ProgramSettings) async throws -> ProgramSettings {
        try await put("program-setting/", body: r, as: ProgramSettings.self)
    }

    func deleteProgramSettings(section: String = "all") async throws {
        _ = try await delete("program-setting/", query: [("section", section)], as: EmptyBody.self)
    }

    func resetProgramSettings() async throws -> ProgramSettings {
        try await post("program-setting/reset", as: ProgramSettings.self)
    }
}
