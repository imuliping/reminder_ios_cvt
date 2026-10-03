//
//  AcceptInviteView.swift
//  Port of shared/AcceptInviteScreen.kt.
//

import SwiftUI

struct AcceptInviteView: View {

    let onBack: () -> Void
    let onAccepted: () -> Void
    @StateObject private var vm = AcceptInviteViewModel()

    @State private var code = ""

    private var isLoading: Bool { vm.acceptState.isLoading }
    private var errorMsg: String? { vm.acceptState.errorMessage }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Join Family Account", onBack: onBack)

            Spacer().frame(height: 48)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: 0xE8F5E9))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppGreen)
                    )

                Spacer().frame(height: 24)

                Text("Enter your invite code")
                    .font(appFont(22, .bold))
                    .foregroundStyle(TextDark)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("Enter the 6-digit code you received to join the family account.")
                    .font(appFont(14))
                    .foregroundStyle(TextGray)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 36)

                TextField("6-digit code", text: $code)
                    .font(.system(size: 28 * AppFontSize.shared.scale, weight: .bold))
                    .multilineTextAlignment(.center)
                    .tracking(8)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .rounded(16)
                    .roundedBorder(code.isEmpty ? BorderGray : AppGreen, 1, radius: 16)
                    .onChange(of: code) { _, newValue in
                        let filtered = newValue.digitsOnly
                        code = filtered.count <= 6 ? filtered : String(filtered.prefix(6))
                        vm.clearError()
                    }

                if let errorMsg {
                    Spacer().frame(height: 8)
                    Text(errorMsg)
                        .font(appFont(13))
                        .foregroundStyle(DangerRed)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 28)

                Button {
                    vm.acceptInvite(code)
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join Account").font(appFont(16, .semibold)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(code.count == 6 && !isLoading ? AppGreen : AppGreen.opacity(0.5))
                    .rounded(50)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || code.count != 6)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color(hex: 0xF7F7F7))
        .onChange(of: vm.acceptState.isSuccess) { _, success in
            if success { onAccepted() }
        }
    }
}
