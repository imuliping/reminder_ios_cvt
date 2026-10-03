//
//  LoginView.swift
//  Port of shared/LoginScreen.kt.
//

import SwiftUI

struct LoginView: View {

    @ObservedObject var vm: LoginViewModel
    var onLoginSuccess: () -> Void = {}
    var onSignupClick: () -> Void = {}
    var onForgotPasswordClick: () -> Void = {}

    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @State private var showSupportDialog = false

    var body: some View {
        ZStack(alignment: .top) {
            PageBg.ignoresSafeArea()

            // Green curved top background
            GeometryReader { geo in
                Ellipse()
                    .fill(Color(hex: 0xBDD9C5))
                    .frame(width: geo.size.width * 2.2, height: 560)
                    .position(x: geo.size.width / 2, y: 60)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 160)

                    Text("Log In")
                        .font(.system(size: 36 * AppFontSize.shared.scale, weight: .bold))
                        .italic()
                        .foregroundStyle(BrownTitle)
                        .tracking(1)

                    Spacer().frame(height: 48)

                    // Email field
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill").foregroundStyle(.gray)
                        TextField("Email", text: $email)
                            .font(appFont(16))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .outlinedField()

                    Spacer().frame(height: 16)

                    // Password field
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundStyle(.gray)
                        if passwordVisible {
                            TextField("Password", text: $password)
                                .font(appFont(16))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password)
                                .font(appFont(16))
                                .textInputAutocapitalization(.never)
                        }
                        Button { passwordVisible.toggle() } label: {
                            Text(passwordVisible ? "🙈" : "👁").font(appFont(16))
                        }
                        .buttonStyle(.plain)
                    }
                    .outlinedField()

                    Spacer().frame(height: 12)

                    // Forgot password
                    HStack {
                        Spacer()
                        Button(action: onForgotPasswordClick) {
                            Text("Forgot password?").font(appFont(14)).foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 28)

                    PrimaryButton(title: vm.state.isLoading ? "Logging in..." : "Login",
                                  enabled: !vm.state.isLoading) {
                        vm.login(email: email, password: password)
                    }

                    Spacer().frame(height: 20)

                    // Register row
                    HStack(spacing: 2) {
                        Text("Don't have an account?").font(appFont(14)).foregroundStyle(.gray)
                        Button(action: onSignupClick) {
                            Text("Register").font(appFont(14, .bold)).foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }

                    if let message = vm.state.errorMessage {
                        Spacer().frame(height: 8)
                        Text(message).font(appFont(14)).foregroundStyle(.red)
                    }

                    Spacer().frame(height: 24)

                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(appFont(11))
                        .foregroundStyle(TextGray.opacity(0.6))

                    Spacer().frame(height: 4)

                    ContactSupportButton(showSheet: $showSupportDialog)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 36)
            }
        }
        .onChange(of: vm.state.isSuccess) { _, success in
            if success { onLoginSuccess() }
        }
        .sheet(isPresented: $showSupportDialog) {
            SupportLogSheet(
                title: "Contact Support",
                explanation: "Having trouble logging in? Send us your debug log and we'll help.",
                confirmLabel: "Send Log",
                isPresented: $showSupportDialog
            )
        }
    }
}
