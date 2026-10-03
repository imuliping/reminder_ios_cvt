//
//  ForgotPasswordView.swift
//  Port of shared/ForgotPasswordScreen.kt.
//

import SwiftUI

struct ForgotPasswordView: View {

    let onBack: () -> Void
    let onResetComplete: () -> Void
    @StateObject private var vm = ForgotPasswordViewModel()

    @State private var identifier = ""
    @State private var channel = "email"
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordVisible = false

    private var isLoading: Bool { vm.requestState.isLoading }
    private var errorMsg: String? { vm.requestState.errorMessage }

    var body: some View {
        ZStack(alignment: .top) {
            PageBg.ignoresSafeArea()
            Color(hex: 0xBDD9C5)
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if case .enterCode = vm.step { vm.goBackToIdentifier() } else { onBack() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(TextDark)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, 4)

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)
                        stepContent
                    }
                    .padding(.horizontal, 36)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {

        case .enterIdentifier:
            heading("Reset Password")
            Spacer().frame(height: 12)
            Text("Enter your email or phone number and we'll send you a code to reset your password.")
                .font(appFont(14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 28)

            HStack(spacing: 12) {
                ChannelChip(label: "Email", selected: channel == "email") {
                    channel = "email"; vm.clearError()
                }
                ChannelChip(label: "Phone", selected: channel == "phone") {
                    channel = "phone"; vm.clearError()
                }
            }
            Spacer().frame(height: 16)

            HStack(spacing: 10) {
                Image(systemName: channel == "email" ? "envelope.fill" : "phone.fill")
                    .foregroundStyle(.gray)
                TextField(channel == "email" ? "Email" : "Phone number", text: $identifier)
                    .font(appFont(16))
                    .keyboardType(channel == "email" ? .emailAddress : .phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: identifier) { _, _ in vm.clearError() }
            }
            .outlinedField()

            errorText
            Spacer().frame(height: 28)
            PrimaryButton(title: isLoading ? "Sending..." : "Send Code",
                          enabled: !isLoading && identifier.isNotBlank) {
                vm.requestCode(identifier: identifier.trimmingCharacters(in: .whitespaces), channel: channel)
            }

        case .enterCode:
            heading("Enter Code")
            Spacer().frame(height: 12)
            Text("We sent a code to \(vm.destination ?? "your \(channel)"). Enter it below.")
                .font(appFont(14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 28)

            HStack(spacing: 10) {
                Image(systemName: "number").foregroundStyle(.gray)
                TextField("Code", text: $code)
                    .font(appFont(16))
                    .keyboardType(.numberPad)
                    .onChange(of: code) { _, v in code = v.digitsOnly; vm.clearError() }
            }
            .outlinedField()

            errorText
            Spacer().frame(height: 28)
            PrimaryButton(title: isLoading ? "Verifying..." : "Verify Code",
                          enabled: !isLoading && code.isNotBlank) {
                vm.verifyCode(code.trimmingCharacters(in: .whitespaces))
            }
            Spacer().frame(height: 16)
            Button {
                vm.resendCode(identifier: identifier.trimmingCharacters(in: .whitespaces), channel: channel)
            } label: {
                Text("Resend code").font(appFont(14)).foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

        case .enterNewPassword:
            heading("New Password")
            Spacer().frame(height: 12)
            Text("Choose a new password for your account.")
                .font(appFont(14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 28)

            HStack(spacing: 10) {
                Image(systemName: "lock.fill").foregroundStyle(.gray)
                if passwordVisible {
                    TextField("New password", text: $newPassword).font(appFont(16))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } else {
                    SecureField("New password", text: $newPassword).font(appFont(16))
                }
                Button { passwordVisible.toggle() } label: {
                    Text(passwordVisible ? "🙈" : "👁").font(appFont(16))
                }
                .buttonStyle(.plain)
            }
            .outlinedField()
            .onChange(of: newPassword) { _, _ in vm.clearError() }

            Spacer().frame(height: 16)

            HStack(spacing: 10) {
                Image(systemName: "lock.fill").foregroundStyle(.gray)
                if passwordVisible {
                    TextField("Confirm new password", text: $confirmPassword).font(appFont(16))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } else {
                    SecureField("Confirm new password", text: $confirmPassword).font(appFont(16))
                }
            }
            .outlinedField()
            .onChange(of: confirmPassword) { _, _ in vm.clearError() }

            errorText
            Spacer().frame(height: 28)
            PrimaryButton(title: isLoading ? "Saving..." : "Reset Password",
                          enabled: !isLoading && newPassword.isNotBlank && confirmPassword.isNotBlank) {
                vm.resetPassword(password: newPassword, passwordConfirmation: confirmPassword)
            }

        case .done:
            Spacer().frame(height: 40)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppGreen)
            Spacer().frame(height: 16)
            Text("Password Reset").font(appFont(24, .bold)).foregroundStyle(BrownTitle)
            Spacer().frame(height: 8)
            Text("Your password has been updated. You can now log in.")
                .font(appFont(14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 28)
            PrimaryButton(title: "Back to Login") { onResetComplete() }
        }
    }

    @ViewBuilder
    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30 * AppFontSize.shared.scale, weight: .bold))
            .italic()
            .foregroundStyle(BrownTitle)
            .tracking(1)
    }

    @ViewBuilder
    private var errorText: some View {
        if let errorMsg {
            Spacer().frame(height: 8)
            Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
        }
    }
}

private struct ChannelChip: View {
    let label: String
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text(label)
                .font(appFont(15, selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Color.gray)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? GreenButton : FieldBg)
                .rounded(50)
        }
        .buttonStyle(.plain)
    }
}
