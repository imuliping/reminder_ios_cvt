//
//  AuthViewModels.swift
//  Ports of shared/LoginViewModel.kt, the SignupViewModel in
//  shared/SignUpScreen.kt, the ForgotPasswordViewModel in
//  shared/ForgotPasswordScreen.kt and the AcceptInviteViewModel in
//  shared/AcceptInviteScreen.kt.
//

import Foundation
import Combine

// ── Login ─────────────────────────────────────────────────────────

enum LoginState {
    case idle
    case loading
    case success(String)
    case error(String)

    var isLoading: Bool { if case .loading = self { return true }; return false }
    var errorMessage: String? { if case .error(let m) = self { return m }; return nil }
    var isSuccess: Bool { if case .success = self { return true }; return false }
}

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var state: LoginState = .idle

    func login(email: String, password: String) {
        Task {
            state = .loading
            await AppRepository.login(email: email, password: password).fold(
                onSuccess: { response in
                    TokenManager.saveToken(response.accessToken)
                    if let role = response.role { TokenManager.saveRoleId(role) }
                    TokenManager.saveAutoLogoutMinutes(response.autoLogoutMinutes)
                    TokenManager.saveLastActivity()

                    // Save user info from /me
                    await AppRepository.getMe().onSuccess { me in
                        TokenManager.saveUserId(me.userId ?? me.id ?? "")
                        TokenManager.saveUsername(me.username)
                        if let fid = me.familyAccountId { TokenManager.saveFamilyAccountId(fid) }
                        if let tz = me.timeZone { TokenManager.saveUserTimeZone(tz) }
                    }

                    let deviceTimeZone = TimeZone.current.identifier
                    if TokenManager.getLastSyncedTimeZone() != deviceTimeZone {
                        await AppRepository.updateMyTimeZone(timeZone: deviceTimeZone)
                            .onSuccess { response in
                                TokenManager.saveUserTimeZone(response.timeZone)
                                TokenManager.saveLastSyncedTimeZone(response.timeZone)
                            }
                            .onFailure { LogManager.logError("Time zone sync failed: \($0.message)") }
                    }

                    // For family/caregiver — fetch the linked senior from the API
                    let role = response.role?.lowercased() ?? ""
                    if role.contains("family") || role.contains("caregiver") {
                        await AppRepository.getMySeniors().fold(
                            onSuccess: { seniors in
                                LogManager.logInfo("getMySeniors: \(seniors.count) found")
                                if let senior = seniors.first {
                                    TokenManager.saveSeniorUserId(senior.userId ?? "")
                                    TokenManager.saveSeniorName(senior.name ?? "Senior")
                                    LogManager.logInfo("Saved seniorUserId: \(senior.userId ?? "")")

                                    // If familyAccountId wasn't in /me, take it from the senior —
                                    // caregivers may not have one on their own account.
                                    if TokenManager.getFamilyAccountId().isNullOrBlank,
                                       let fid = senior.familyAccountId {
                                        TokenManager.saveFamilyAccountId(fid)
                                        LogManager.logInfo("Saved familyAccountId from senior: \(fid)")
                                    }
                                }
                            },
                            onFailure: { LogManager.logError("getMySeniors failed: \($0.message)") }
                        )
                    }

                    // Register the APNs device token with the backend
                    // (Android registered the FCM token at this point).
                    if let token = PushManager.shared.deviceToken {
                        await registerDeviceToken(token)
                    } else {
                        LogManager.logInfo("No APNs token yet — it registers once APNs responds")
                    }

                    state = .success(response.accessToken)
                },
                onFailure: { error in
                    state = .error(error.message.isEmpty
                        ? "Login failed. Check your credentials."
                        : error.message)
                }
            )
        }
    }

    func logout() {
        Task {
            await unregisterDeviceToken()
            _ = await AppRepository.revokeSession()
            AppRepository.logout()
            state = .idle
        }
    }
}

// ── Signup ────────────────────────────────────────────────────────

enum SignupState {
    case idle, loading, success
    case error(String)

    var isLoading: Bool { if case .loading = self { return true }; return false }
    var errorMessage: String? { if case .error(let m) = self { return m }; return nil }
    var isSuccess: Bool { if case .success = self { return true }; return false }
}

@MainActor
final class SignupViewModel: ObservableObject {

    @Published var state: SignupState = .idle

    func signup(email: String, username: String, age: Int, password: String,
                passwordConfirmation: String, roleId: String?, familyAccountId: String?) {
        Task {
            state = .loading
            await AppRepository.signup(
                email: email, username: username, age: age, password: password,
                passwordConfirmation: passwordConfirmation,
                familyAccountId: familyAccountId, roleId: roleId
            ).fold(
                onSuccess: { response in
                    TokenManager.saveToken(response.accessToken)
                    if let role = response.role { TokenManager.saveRoleId(role) }
                    await AppRepository.getMe().onSuccess { me in
                        TokenManager.saveUserId(me.userId ?? me.id ?? "")
                        TokenManager.saveUsername(me.username)
                        if let fid = me.familyAccountId { TokenManager.saveFamilyAccountId(fid) }
                        if let tz = me.timeZone { TokenManager.saveUserTimeZone(tz) }
                    }
                    state = .success
                },
                onFailure: { state = .error($0.message.isEmpty ? "Signup failed. Please try again." : $0.message) }
            )
        }
    }

    func resetState() { state = .idle }
}

// ── Forgot Password ───────────────────────────────────────────────

enum ForgotPasswordStep {
    case enterIdentifier, enterCode, enterNewPassword, done
}

@MainActor
final class ForgotPasswordViewModel: ObservableObject {

    @Published var step: ForgotPasswordStep = .enterIdentifier
    @Published var requestState: UiState<Void> = .idle
    @Published var destination: String?

    private var resetRequestId: String?
    private var resetToken: String?

    func requestCode(identifier: String, channel: String) {
        Task {
            requestState = .loading
            let email = channel == "email" ? identifier : nil
            let phone = channel == "phone" ? identifier : nil
            await AppRepository.forgotPasswordRequest(identifier: identifier, channel: channel,
                                                      email: email, phone: phone).fold(
                onSuccess: { resp in
                    resetRequestId = resp.resetRequestId
                    destination = resp.destination
                    requestState = .success(())
                    step = .enterCode
                },
                onFailure: {
                    requestState = .error($0.message.isEmpty
                        ? "Could not send reset code. Please check your details and try again."
                        : $0.message)
                }
            )
        }
    }

    func verifyCode(_ code: String) {
        Task {
            guard let requestId = resetRequestId else {
                requestState = .error("Something went wrong. Please start over.")
                return
            }
            requestState = .loading
            await AppRepository.forgotPasswordVerify(resetRequestId: requestId, code: code).fold(
                onSuccess: { resp in
                    resetToken = resp.resetToken
                    requestState = .success(())
                    step = .enterNewPassword
                },
                onFailure: {
                    requestState = .error($0.message.isEmpty
                        ? "That code didn't work. Please check it and try again."
                        : $0.message)
                }
            )
        }
    }

    func resetPassword(password: String, passwordConfirmation: String) {
        Task {
            guard let requestId = resetRequestId, let token = resetToken else {
                requestState = .error("Something went wrong. Please start over.")
                return
            }
            if password != passwordConfirmation {
                requestState = .error("Passwords don't match.")
                return
            }
            requestState = .loading
            await AppRepository.forgotPasswordReset(resetRequestId: requestId, resetToken: token,
                                                    password: password,
                                                    passwordConfirmation: passwordConfirmation).fold(
                onSuccess: { _ in
                    requestState = .success(())
                    step = .done
                },
                onFailure: {
                    requestState = .error($0.message.isEmpty
                        ? "Could not reset your password. Please try again."
                        : $0.message)
                }
            )
        }
    }

    func resendCode(identifier: String, channel: String) {
        requestCode(identifier: identifier, channel: channel)
    }

    func clearError() {
        if case .error = requestState { requestState = .idle }
    }

    func goBackToIdentifier() {
        resetRequestId = nil
        resetToken = nil
        requestState = .idle
        step = .enterIdentifier
    }
}

// ── Accept Invite ─────────────────────────────────────────────────

@MainActor
final class AcceptInviteViewModel: ObservableObject {

    @Published var acceptState: UiState<String> = .idle

    func acceptInvite(_ token: String) {
        Task {
            acceptState = .loading
            await AppRepository.acceptInvite(token: token.trimmingCharacters(in: .whitespaces)).fold(
                onSuccess: { acceptState = .success($0) },
                onFailure: {
                    acceptState = .error($0.message.isEmpty
                        ? "Invalid code. Please check and try again."
                        : $0.message)
                }
            )
        }
    }

    func clearError() {
        if case .error = acceptState { acceptState = .idle }
    }
}
