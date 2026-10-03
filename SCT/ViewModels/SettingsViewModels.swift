//
//  SettingsViewModels.swift
//  Ports of shared/SecurityViewModel.kt, shared/GeneralSettingsViewModel.kt,
//  shared/PrivacySecurityViewModel.kt, shared/NotificationSettingsViewModel.kt
//  and the ResetViewModel in shared/ResetScreen.kt.
//

import Foundation

// ── Security ──────────────────────────────────────────────────────

@MainActor
final class SecurityViewModel: ObservableObject {

    @Published var settingsState: UiState<ProgramSettings> = .idle
    @Published var saveState: UiState<ProgramSettings> = .idle

    private var workingCopy: ProgramSettings?

    init() { loadSettings() }

    func loadSettings() {
        Task {
            settingsState = .loading
            await AppRepository.getProgramSettings().fold(
                onSuccess: {
                    workingCopy = $0
                    settingsState = .success($0)
                },
                onFailure: { settingsState = .error($0.message.isEmpty ? "Failed to load settings" : $0.message) }
            )
        }
    }

    func updateAccountSecurity(_ update: (AccountSecurity) -> AccountSecurity) {
        guard var current = workingCopy else { return }
        current.accountSecurity = update(current.accountSecurity ?? AccountSecurity())
        workingCopy = current
        settingsState = .success(current)
    }

    func save() {
        guard let current = workingCopy else { return }
        Task {
            saveState = .loading
            await AppRepository.updateProgramSettings(current).fold(
                onSuccess: {
                    workingCopy = $0
                    settingsState = .success($0)
                    saveState = .success($0)
                },
                onFailure: { saveState = .error($0.message.isEmpty ? "Failed to save" : $0.message) }
            )
        }
    }
}

// ── General Settings ──────────────────────────────────────────────

@MainActor
final class GeneralSettingsViewModel: ObservableObject {

    @Published var settingsState: UiState<ProgramSettings> = .idle
    @Published var saveState: UiState<ProgramSettings> = .idle

    /// Local copy of the full settings object, mutated as the user edits.
    private var workingCopy: ProgramSettings?

    /// The fontSize the backend returned — we always send this back unchanged
    /// because font size is UI-only (stored in AppFontSize locally).
    private var backendFontSize: String?

    init() { loadSettings() }

    func loadSettings() {
        Task {
            settingsState = .loading
            await AppRepository.getProgramSettings().fold(
                onSuccess: {
                    workingCopy = $0
                    backendFontSize = $0.accessibilityUx?.fontSize
                    settingsState = .success($0)
                },
                onFailure: { settingsState = .error($0.message.isEmpty ? "Failed to load settings" : $0.message) }
            )
        }
    }

    func updateTaskPreferences(_ update: (TaskPreferences) -> TaskPreferences) {
        guard var current = workingCopy else { return }
        current.taskPreferences = update(current.taskPreferences ?? TaskPreferences())
        workingCopy = current
        settingsState = .success(current)
    }

    func updateAccessibility(_ update: (AccessibilityUx) -> AccessibilityUx) {
        guard var current = workingCopy else { return }
        current.accessibilityUx = update(current.accessibilityUx ?? AccessibilityUx())
        workingCopy = current
        settingsState = .success(current)
    }

    func save() {
        guard let current = workingCopy else { return }
        Task {
            saveState = .loading
            // Restore the backend's original fontSize before saving — font size is
            // UI-only and the backend is unreliable with certain fontSize values.
            var toSave = current
            if let backendFontSize, var ux = toSave.accessibilityUx {
                ux.fontSize = backendFontSize
                toSave.accessibilityUx = ux
            }
            await AppRepository.updateProgramSettings(toSave).fold(
                onSuccess: {
                    workingCopy = $0
                    backendFontSize = $0.accessibilityUx?.fontSize
                    settingsState = .success($0)
                    saveState = .success($0)
                },
                onFailure: { saveState = .error($0.message.isEmpty ? "Failed to save settings" : $0.message) }
            )
        }
    }
}

// ── Privacy & Security (unreachable on Android too — kept for parity) ──

@MainActor
final class PrivacySecurityViewModel: ObservableObject {

    @Published var settingsState: UiState<ProgramSettings> = .idle
    @Published var saveState: UiState<ProgramSettings> = .idle
    @Published var resetState: UiState<Void> = .idle

    private var workingCopy: ProgramSettings?

    init() { loadSettings() }

    func loadSettings() {
        Task {
            settingsState = .loading
            await AppRepository.getProgramSettings().fold(
                onSuccess: {
                    workingCopy = $0
                    settingsState = .success($0)
                },
                onFailure: { settingsState = .error($0.message.isEmpty ? "Failed to load settings" : $0.message) }
            )
        }
    }

    func updateAccountSecurity(_ update: (AccountSecurity) -> AccountSecurity) {
        guard var current = workingCopy else { return }
        current.accountSecurity = update(current.accountSecurity ?? AccountSecurity())
        workingCopy = current
        settingsState = .success(current)
    }

    func updateDataSharingConsent(_ update: (DataSharingConsent) -> DataSharingConsent) {
        updateAccountSecurity { security in
            var copy = security
            copy.dataSharingConsent = update(security.dataSharingConsent ?? DataSharingConsent())
            return copy
        }
    }

    func save() {
        guard let current = workingCopy else { return }
        Task {
            saveState = .loading
            await AppRepository.updateProgramSettings(current).fold(
                onSuccess: {
                    workingCopy = $0
                    settingsState = .success($0)
                    saveState = .success($0)
                },
                onFailure: { saveState = .error($0.message.isEmpty ? "Failed to save settings" : $0.message) }
            )
        }
    }

    /// Reset settings to defaults server-side, then reload.
    func resetSettings(section: String = "all") {
        Task {
            resetState = .loading
            await AppRepository.deleteProgramSettings(section: section).fold(
                onSuccess: { _ in
                    resetState = .success(())
                    loadSettings()
                },
                onFailure: { resetState = .error($0.message.isEmpty ? "Failed to reset settings" : $0.message) }
            )
        }
    }
}

// ── Notification Settings ─────────────────────────────────────────

@MainActor
final class NotificationSettingsViewModel: ObservableObject {

    @Published var policiesState: UiState<[NotificationPolicy]> = .idle
    @Published var priorityLevels: [PriorityLevel] = []

    init() {
        loadPriorityLevels()
        loadPolicies()
    }

    func loadPriorityLevels() {
        Task {
            await AppRepository.getPriorityLevels().onSuccess { priorityLevels = $0 }
        }
    }

    func loadPolicies() {
        Task {
            policiesState = .loading
            await AppRepository.getMyNotificationPolicies().fold(
                onSuccess: { policiesState = .success($0) },
                onFailure: {
                    policiesState = .error($0.message.isEmpty
                        ? "Failed to load notification settings" : $0.message)
                }
            )
        }
    }

    func setEnabled(_ policy: NotificationPolicy, _ enabled: Bool) {
        var copy = policy
        copy.enabled = enabled
        updatePolicy(copy)
    }

    func setRequiresAcknowledgement(_ policy: NotificationPolicy, _ value: Bool) {
        var copy = policy
        copy.requiresAcknowledgement = value
        updatePolicy(copy)
    }

    func setRepeatInterval(_ policy: NotificationPolicy, _ seconds: Int) {
        var copy = policy
        copy.repeatIntervalSeconds = seconds
        updatePolicy(copy)
    }

    private func updatePolicy(_ policy: NotificationPolicy) {
        Task {
            let result: Result<NotificationPolicy, Error>
            if let id = policy.notificationPolicyId {
                result = await AppRepository.updateMyNotificationPolicy(
                    id: id,
                    request: UpdateNotificationPolicyRequest(
                        enabled: policy.enabled ?? true,
                        repeatIntervalSeconds: policy.repeatIntervalSeconds ?? 0,
                        maxRepeats: policy.maxRepeats ?? 0,
                        requiresAcknowledgement: policy.requiresAcknowledgement ?? false,
                        requiresConfirmation: policy.requiresConfirmation ?? false,
                        requiresEscalation: policy.requiresEscalation ?? false,
                        escalationAfterMinutes: policy.escalationAfterMinutes ?? 0,
                        overrideSilentMode: policy.overrideSilentMode ?? false,
                        escalateToUserIds: policy.escalateToUserIds ?? []
                    )
                )
            } else {
                result = await AppRepository.createMyNotificationPolicy(
                    CreateNotificationPolicyRequest(
                        priorityLevelId: policy.priorityLevelId,
                        taskRoleId: policy.taskRoleId,
                        enabled: policy.enabled ?? true,
                        repeatIntervalSeconds: policy.repeatIntervalSeconds ?? 0,
                        maxRepeats: policy.maxRepeats ?? 0,
                        requiresAcknowledgement: policy.requiresAcknowledgement ?? false,
                        requiresConfirmation: policy.requiresConfirmation ?? false,
                        requiresEscalation: policy.requiresEscalation ?? false,
                        escalationAfterMinutes: policy.escalationAfterMinutes ?? 0,
                        overrideSilentMode: policy.overrideSilentMode ?? false,
                        escalateToUserIds: policy.escalateToUserIds ?? []
                    )
                )
            }
            await result
                .onSuccess { _ in loadPolicies() }
                .onFailure { LogManager.logError("updatePolicy failed: \($0.message)") }
        }
    }
}

// ── Reset ─────────────────────────────────────────────────────────

@MainActor
final class ResetViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMsg: String?

    func resetAllSettings(onDone: @escaping () -> Void) {
        Task {
            isLoading = true
            errorMsg = nil
            await AppRepository.resetProgramSettings().fold(
                onSuccess: { _ in isLoading = false; onDone() },
                onFailure: { isLoading = false; errorMsg = $0.message.isEmpty ? "Failed to reset settings" : $0.message }
            )
        }
    }

    func resetNotificationPreferences(onDone: @escaping () -> Void) {
        Task {
            isLoading = true
            errorMsg = nil
            await AppRepository.deleteProgramSettings(section: "notificationsAlerts").fold(
                onSuccess: { _ in isLoading = false; onDone() },
                onFailure: { isLoading = false; errorMsg = $0.message.isEmpty ? "Failed" : $0.message }
            )
        }
    }

    func resetDisplaySettings(onDone: @escaping () -> Void) {
        Task {
            isLoading = true
            errorMsg = nil
            await AppRepository.deleteProgramSettings(section: "accessibilityUx").fold(
                onSuccess: { _ in isLoading = false; onDone() },
                onFailure: { isLoading = false; errorMsg = $0.message.isEmpty ? "Failed" : $0.message }
            )
        }
    }
}
