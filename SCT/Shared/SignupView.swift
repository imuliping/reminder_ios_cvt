//
//  SignupView.swift
//  Port of shared/SignUpScreen.kt (the SignupScreen composable).
//

import SwiftUI

struct SignupView: View {

    let onSignupSuccess: () -> Void
    let onBack: () -> Void
    @StateObject private var vm = SignupViewModel()

    @State private var email = ""
    @State private var username = ""
    @State private var age = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var familyAccountId = ""
    @State private var passwordVisible = false
    @State private var confirmVisible = false
    @State private var errorMsg = ""

    /// Role dropdown — maps display name to roleId
    private let roleOptions: [(String, String)] = [
        ("Senior", RoleIds.SENIOR),
        ("Family Member", RoleIds.FAMILY),
        ("Professional Caregiver", RoleIds.CAREGIVER)
    ]
    @State private var selectedRoleIndex = 0

    var body: some View {
        ZStack(alignment: .top) {
            PageBg.ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .fill(Color(hex: 0xBDD9C5))
                    .frame(width: geo.size.width * 2.2, height: 560)
                    .position(x: geo.size.width / 2, y: 60)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 150)

                    Text("Sign Up")
                        .font(.system(size: 36 * AppFontSize.shared.scale, weight: .bold))
                        .italic()
                        .foregroundStyle(BrownTitle)
                        .tracking(1)

                    Spacer().frame(height: 40)

                    // Email
                    HStack(spacing: 10) {
                        Text("✉️").font(appFont(18))
                        TextField("Email", text: $email)
                            .font(appFont(16))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .outlinedField()

                    Spacer().frame(height: 14)

                    // Username
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill").foregroundStyle(.gray)
                        TextField("Username", text: $username)
                            .font(appFont(16))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .outlinedField()

                    Spacer().frame(height: 14)

                    // Age
                    HStack(spacing: 10) {
                        Text("🎂").font(appFont(18))
                        TextField("Age", text: $age)
                            .font(appFont(16))
                            .keyboardType(.numberPad)
                            .onChange(of: age) { _, v in age = v.digitsOnly }
                    }
                    .outlinedField()

                    Spacer().frame(height: 14)

                    // Password
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundStyle(.gray)
                        if passwordVisible {
                            TextField("Password", text: $password).font(appFont(16))
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password).font(appFont(16))
                        }
                        Button { passwordVisible.toggle() } label: {
                            Text(passwordVisible ? "🙈" : "👁").font(appFont(16))
                        }
                        .buttonStyle(.plain)
                    }
                    .outlinedField()

                    Spacer().frame(height: 14)

                    // Confirm Password
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundStyle(.gray)
                        if confirmVisible {
                            TextField("Confirm Pass...", text: $confirmPassword).font(appFont(16))
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        } else {
                            SecureField("Confirm Pass...", text: $confirmPassword).font(appFont(16))
                        }
                        Button { confirmVisible.toggle() } label: {
                            Text(confirmVisible ? "🙈" : "👁").font(appFont(16))
                        }
                        .buttonStyle(.plain)
                    }
                    .outlinedField()

                    Spacer().frame(height: 14)

                    // Role dropdown
                    Menu {
                        ForEach(roleOptions.indices, id: \.self) { index in
                            Button(roleOptions[index].0) { selectedRoleIndex = index }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2.fill").foregroundStyle(.gray)
                            Text(roleOptions[selectedRoleIndex].0)
                                .font(appFont(16))
                                .foregroundStyle(TextDark)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundStyle(.gray)
                        }
                        .outlinedField()
                    }

                    Spacer().frame(height: 14)

                    // Family Account ID (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Text("🏠").font(appFont(18))
                            TextField("Family Account ID", text: $familyAccountId)
                                .font(appFont(16))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .outlinedField()
                        Text("Leave blank if you're new")
                            .font(appFont(12))
                            .foregroundStyle(HintGray)
                            .padding(.leading, 16)
                    }

                    Spacer().frame(height: 8)

                    if errorMsg.isNotBlank || vm.state.errorMessage != nil {
                        Text(vm.state.errorMessage ?? errorMsg)
                            .font(appFont(13))
                            .foregroundStyle(.red)
                        Spacer().frame(height: 8)
                    }

                    Spacer().frame(height: 16)

                    PrimaryButton(title: vm.state.isLoading ? "Creating account..." : "Sign Up",
                                  enabled: !vm.state.isLoading) {
                        errorMsg = ""
                        if email.isBlank { errorMsg = "Email is required." }
                        else if username.isBlank { errorMsg = "Username is required." }
                        else if age.isBlank { errorMsg = "Age is required." }
                        else if password.isBlank { errorMsg = "Password is required." }
                        else if password != confirmPassword { errorMsg = "Passwords do not match." }
                        else {
                            vm.signup(
                                email: email.trimmingCharacters(in: .whitespaces),
                                username: username.trimmingCharacters(in: .whitespaces),
                                age: Int(age) ?? 0,
                                password: password,
                                passwordConfirmation: confirmPassword,
                                roleId: roleOptions[selectedRoleIndex].1,
                                familyAccountId: familyAccountId.trimmingCharacters(in: .whitespaces).nonBlank
                            )
                        }
                    }

                    Spacer().frame(height: 20)

                    HStack(spacing: 2) {
                        Text("Already have an account?").font(appFont(14)).foregroundStyle(.gray)
                        Button(action: onBack) {
                            Text("Log In").font(appFont(14, .bold)).foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 36)
            }
        }
        .onChange(of: vm.state.isSuccess) { _, success in
            if success { onSignupSuccess() }
        }
    }
}
