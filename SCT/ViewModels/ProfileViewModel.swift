//
//  ProfileViewModel.swift
//  Port of shared/ProfileViewModel.kt and shared/RelativeAccountsViewModel.kt.
//

import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var meState: UiState<Me> = .idle
    @Published var contactsState: UiState<[EmergencyContact]> = .idle
    @Published var updateState: UiState<User> = .idle
    @Published var timeZoneState: UiState<String> = .idle

    init() {
        loadMe()
        loadEmergencyContacts()
        loadTimeZone()
    }

    func loadMe() {
        Task {
            meState = .loading
            await AppRepository.getMe().fold(
                onSuccess: {
                    TokenManager.saveUsername($0.username)
                    TokenManager.saveUserId($0.userId ?? $0.id ?? "")
                    meState = .success($0)
                },
                onFailure: { meState = .error($0.message.isEmpty ? "Failed to load profile" : $0.message) }
            )
        }
    }

    func updateProfile(userId: String, username: String?, email: String?, age: Int?, phone: String? = nil) {
        Task {
            updateState = .loading
            await AppRepository.updateUser(userId: userId, username: username, email: email,
                                           age: age, phone: phone).fold(
                onSuccess: {
                    updateState = .success($0)
                    loadMe()   // refresh so the UI reflects new values
                },
                onFailure: { updateState = .error($0.message.isEmpty ? "Failed to update profile" : $0.message) }
            )
        }
    }

    func loadEmergencyContacts() {
        Task {
            contactsState = .loading
            await AppRepository.getEmergencyContacts().fold(
                onSuccess: { contactsState = .success($0) },
                onFailure: { contactsState = .error($0.message.isEmpty ? "Failed to load contacts" : $0.message) }
            )
        }
    }

    func addEmergencyContact(name: String, phone: String, relation: String?) {
        Task {
            await AppRepository.createEmergencyContact(name: name, phone: phone, relation: relation)
                .onSuccess { _ in loadEmergencyContacts() }
        }
    }

    func deleteEmergencyContact(id: String) {
        Task {
            await AppRepository.deleteEmergencyContact(id: id)
                .onSuccess { _ in loadEmergencyContacts() }
        }
    }

    // ── Time Zone ───────────────────────────────────────────────
    func loadTimeZone() {
        Task {
            timeZoneState = .loading
            await AppRepository.getMyTimeZone().fold(
                onSuccess: {
                    TokenManager.saveUserTimeZone($0.timeZone)
                    timeZoneState = .success($0.timeZone)
                },
                onFailure: { timeZoneState = .error($0.message.isEmpty ? "Failed to load time zone" : $0.message) }
            )
        }
    }

    func updateTimeZone(_ timeZone: String) {
        Task {
            await AppRepository.updateMyTimeZone(timeZone: timeZone).fold(
                onSuccess: {
                    TokenManager.saveUserTimeZone($0.timeZone)
                    timeZoneState = .success($0.timeZone)
                },
                onFailure: { LogManager.logError("updateTimeZone failed: \($0.message)") }
            )
        }
    }
}

@MainActor
final class RelativeAccountsViewModel: ObservableObject {

    @Published var membersState: UiState<[FamilyMember]> = .idle
    @Published var removeState: UiState<Void> = .idle
    @Published var inviteState: UiState<String> = .idle

    init() { loadMembers() }

    func loadMembers() {
        Task {
            membersState = .loading
            // Try the saved familyAccountId first; caregivers may not have it cached.
            var familyAccountId = TokenManager.getFamilyAccountId()
            if familyAccountId.isNullOrBlank {
                await AppRepository.getMe().onSuccess { me in
                    if let fid = me.familyAccountId {
                        TokenManager.saveFamilyAccountId(fid)
                        familyAccountId = fid
                    }
                }
            }
            guard let fid = familyAccountId, fid.isNotBlank else {
                membersState = .error("No family account found")
                return
            }
            await AppRepository.getFamily(familyAccountId: fid).fold(
                onSuccess: { membersState = .success($0.members ?? []) },
                onFailure: { membersState = .error($0.message.isEmpty ? "Failed to load family members" : $0.message) }
            )
        }
    }

    func removeMember(userId: String) {
        Task {
            removeState = .loading
            guard let familyAccountId = TokenManager.getFamilyAccountId(), familyAccountId.isNotBlank else {
                removeState = .error("No family account found")
                return
            }
            await AppRepository.removeFamilyMember(familyAccountId: familyAccountId, userId: userId).fold(
                onSuccess: { _ in
                    removeState = .success(())
                    loadMembers()
                },
                onFailure: { removeState = .error($0.message.isEmpty ? "Failed to remove member" : $0.message) }
            )
        }
    }

    func inviteMember(roleId: String) {
        Task {
            inviteState = .loading
            guard let familyAccountId = TokenManager.getFamilyAccountId(), familyAccountId.isNotBlank else {
                inviteState = .error("No family account found")
                return
            }
            await AppRepository.createInvite(familyAccountId: familyAccountId, roleId: roleId).fold(
                onSuccess: { inviteState = .success($0) },
                onFailure: { inviteState = .error($0.message.isEmpty ? "Failed to send invite" : $0.message) }
            )
        }
    }

    func clearInviteState() { inviteState = .idle }
}
