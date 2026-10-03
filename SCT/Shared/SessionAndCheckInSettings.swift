import SwiftUI

struct AutoLogoutSettingsView: View {
    @State private var minutes = TokenManager.getAutoLogoutMinutes()
    @State private var isBusy = false
    @State private var errorMessage: String?
    private let options = [0, 5, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Automatic logout").font(appFont(15, .semibold))
            Text("Sign out after a period of inactivity.")
                .font(appFont(12)).foregroundStyle(TextGray)
            Picker("Automatic logout", selection: $minutes) {
                ForEach(options, id: \.self) { value in
                    Text(value == 0 ? "Never" : "\(value) minutes").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isBusy)
            .onChange(of: minutes) { _, value in save(value) }
            if let errorMessage {
                Text(errorMessage).font(appFont(12)).foregroundStyle(DangerRed)
            }
        }
        .padding(16)
        .background(Color.white)
        .rounded(14)
        .padding(.horizontal, 16)
        .task {
            await AppRepository.getSessionSettings()
                .onSuccess {
                    minutes = $0.autoLogoutMinutes
                    TokenManager.saveAutoLogoutMinutes($0.autoLogoutMinutes)
                }
                .onFailure { _ in errorMessage = "Could not load auto-logout settings." }
        }
    }

    private func save(_ value: Int) {
        isBusy = true
        errorMessage = nil
        Task {
            await AppRepository.setSessionSettings(minutes: value)
                .onSuccess {
                    minutes = $0.autoLogoutMinutes
                    TokenManager.saveAutoLogoutMinutes($0.autoLogoutMinutes)
                    TokenManager.saveLastActivity()
                }
                .onFailure { _ in errorMessage = "Could not save. Please try again." }
            isBusy = false
        }
    }
}

struct CheckInSettingsView: View {
    @State private var contacts: [EmergencyContact] = []
    @State private var priorities: [PriorityLevel] = []
    @State private var policies: [NotificationPolicy] = []
    @State private var selected: [Int: Set<String>] = [4: [], 5: []]
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow-ups and check-ins").font(appFont(17, .bold))
            Text("Priority 3: one follow-up after 30 minutes. Priority 4: every 10 minutes, with a check-in after 45 minutes. Priority 5: every 5 minutes, with emergency check-ins.")
                .font(appFont(13))
                .foregroundStyle(TextGray)

            ForEach([4, 5], id: \.self) { level in
                Text(level == 4 ? "Priority 4 — check-in recipients" : "Priority 5 — emergency recipients")
                    .font(appFont(14, .semibold))
                if contacts.isEmpty {
                    Text("No SMS-enabled emergency contacts.")
                        .font(appFont(13)).foregroundStyle(TextGray)
                }
                ForEach(contacts) { contact in
                    let id = contact.contactId ?? contact.id ?? ""
                    Toggle(isOn: Binding(
                        get: { selected[level, default: []].contains(id) },
                        set: { value in
                            if value { selected[level, default: []].insert(id) }
                            else { selected[level, default: []].remove(id) }
                        })) {
                        Text("\(contact.name) · \(contact.phone)").font(appFont(13))
                    }
                    .disabled(id.isBlank || isBusy)
                }
            }

            Button(isBusy ? "Saving..." : "Save check-in recipients") { save() }
                .buttonStyle(.borderedProminent)
                .tint(AppGreen)
                .disabled(isBusy)
            if let errorMessage {
                Text(errorMessage).font(appFont(12)).foregroundStyle(DangerRed)
            }
        }
        .padding(16)
        .background(Color.white)
        .rounded(14)
        .padding(.horizontal, 16)
        .task { load() }
    }

    private func load() {
        isBusy = true
        Task {
            async let contactsResult = AppRepository.getEmergencyContacts()
            async let prioritiesResult = AppRepository.getPriorityLevels()
            async let policiesResult = AppRepository.getMyNotificationPolicies()
            let (contactResponse, priorityResponse, policyResponse) =
                await (contactsResult, prioritiesResult, policiesResult)
            contacts = contactResponse.getOrElse([])
            priorities = priorityResponse.getOrElse([])
            policies = policyResponse.getOrElse([])
            for level in [4, 5] {
                guard let priorityId = priorities.first(where: { $0.priorityLevel == level })?.priorityLevelId,
                      let policy = policies.first(where: { $0.priorityLevelId == priorityId }) else { continue }
                selected[level] = Set(policy.escalateToEmergencyContactIds ?? [])
            }
            isBusy = false
        }
    }

    private func save() {
        isBusy = true
        errorMessage = nil
        Task {
            for level in [4, 5] {
                guard let priorityId = priorities.first(where: { $0.priorityLevel == level })?.priorityLevelId else { continue }
                let old = policies.first { $0.priorityLevelId == priorityId }
                let result = await AppRepository.saveCheckInRecipients(
                    priorityId: priorityId,
                    policyId: old?.notificationPolicyId,
                    users: old?.escalateToUserIds ?? [],
                    contacts: Array(selected[level, default: []]))
                if case .failure(let error) = result {
                    errorMessage = error.message
                    isBusy = false
                    return
                }
            }
            isBusy = false
        }
    }
}
