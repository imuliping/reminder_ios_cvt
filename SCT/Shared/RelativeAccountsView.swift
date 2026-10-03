//
//  RelativeAccountsView.swift
//  Port of shared/RelativeAccountsScreen.kt (incl. InviteDialog + InviteCodeDialog).
//

import SwiftUI

struct RelativeAccountsView: View {

    let onBack: () -> Void
    @StateObject private var vm = RelativeAccountsViewModel()

    @State private var showInviteDialog = false
    @State private var showCodeDialog = false
    @State private var showLinkedChanges = false
    @State private var generatedCode = ""

    private let seniorRoleIds: Set<String> = ["c8bac46a-8a46-5c17-a84b-59e3bc85fd62", "senior"]
    private let familyRoleIds: Set<String> = ["58243a78-29ac-509b-92c8-98ee04ab8e99", "family member"]
    private let caregiverRoleIds: Set<String> = ["a48ad94d-0e41-59d1-9166-f70ae343f432",
                                                "caregiver", "professional caregiver"]

    private var isSenior: Bool { TokenManager.isSenior() }
    private var members: [FamilyMember] { vm.membersState.data ?? [] }

    var body: some View {
        let myUserId = TokenManager.getUserId()
        let otherMembers = members.filter { $0.userId != myUserId }
        let familyMembers = otherMembers.filter { familyRoleIds.contains($0.roleId?.lowercased() ?? "") }
        let caregivers = otherMembers.filter { caregiverRoleIds.contains($0.roleId?.lowercased() ?? "") }
        let otherRoles = otherMembers.filter {
            let r = $0.roleId?.lowercased() ?? ""
            return !seniorRoleIds.contains(r) && !familyRoleIds.contains(r) && !caregiverRoleIds.contains(r)
        }
        let pending = members.filter { $0.status?.lowercased() == "pending" }

        VStack(spacing: 0) {
            TopBar(title: "Relative Accounts", onBack: onBack)

            ScrollView {
                VStack(spacing: 12) {
                    // ── Invite button (senior only) ───────────────
                    if isSenior {
                        Button { showInviteDialog = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.plus").font(.system(size: 18))
                                Text("Invite someone").font(appFont(16, .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppGreen)
                            .rounded(50)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Suggested changes and approvals") {
                        showLinkedChanges = true
                    }
                    .font(appFont(15, .semibold))

                    if !familyMembers.isEmpty {
                        memberSectionHeader("FAMILY MEMBER", familyMembers.count)
                        memberGroupCard(familyMembers)
                    }

                    if !caregivers.isEmpty {
                        memberSectionHeader("CAREGIVER", caregivers.count)
                        memberGroupCard(caregivers)
                    }

                    if !otherRoles.isEmpty {
                        memberSectionHeader("OTHER", otherRoles.count)
                        memberGroupCard(otherRoles)
                    }

                    // ── Pending Invitations ───────────────────────
                    if !pending.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PENDING INVITATIONS")
                                .font(appFont(11, .bold))
                                .foregroundStyle(Color(hex: 0xB8860B))
                                .tracking(1)
                            ForEach(pending) { member in
                                HStack(spacing: 14) {
                                    MemberAvatar(initials: member.username ?? member.name ?? "?",
                                                 bgColor: Color(hex: 0xEEEEEE),
                                                 textColor: TextDark)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.username ?? member.name ?? "Unknown")
                                            .font(appFont(15, .semibold))
                                        Text("Invited via email · \(member.createdAt?.take(10) ?? "recently")")
                                            .font(appFont(13)).foregroundStyle(TextGray)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: 0xFFF8F0))
                        .rounded(14)
                    }

                    // Empty state
                    if members.isEmpty, vm.membersState.isSuccess {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(.lightGray))
                            Text("No linked accounts yet.").font(appFont(15)).foregroundStyle(TextGray)
                            if isSenior {
                                Text("Tap Invite to add family members or caregivers.")
                                    .font(appFont(13))
                                    .foregroundStyle(TextGray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.vertical, 32)
                    }

                    if vm.membersState.isLoading {
                        ProgressView().tint(AppGreen).padding(32)
                    }

                    if let message = vm.membersState.errorMessage {
                        Text(message).font(appFont(14)).foregroundStyle(.red).padding(8)
                    }

                    Spacer().frame(height: 16)
                }
                .padding(16)
            }
        }
        .background(Color(hex: 0xF7F7F7))
        .onChange(of: vm.inviteState.isSuccess) { _, success in
            // Show the code dialog when the invite succeeds
            guard success, let code = vm.inviteState.data, code.isNotBlank else { return }
            generatedCode = code
            showInviteDialog = false
            showCodeDialog = true
        }
        .sheet(isPresented: $showInviteDialog) {
            InviteDialog(
                isLoading: vm.inviteState.isLoading,
                errorMsg: vm.inviteState.errorMessage,
                onDismiss: { showInviteDialog = false; vm.clearInviteState() },
                onInvite: { role in vm.inviteMember(roleId: role) }
            )
        }
        .sheet(isPresented: $showCodeDialog) {
            InviteCodeDialog(code: generatedCode) {
                showCodeDialog = false
                vm.clearInviteState()
                vm.loadMembers()
            }
        }
        .fullScreenCover(isPresented: $showLinkedChanges) {
            LinkedChangesView(onBack: { showLinkedChanges = false })
        }
    }

    // ── Helpers ───────────────────────────────────────────────────

    private func memberSectionHeader(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label).font(appFont(11, .bold)).foregroundStyle(TextGray).tracking(1)
            Spacer()
            Text("\(count) linked").font(appFont(11)).foregroundStyle(TextGray)
        }
        .padding(.horizontal, 4)
    }

    private func memberGroupCard(_ group: [FamilyMember]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.enumerated()), id: \.offset) { index, member in
                MemberRow(member: member) { vm.removeMember(userId: member.userId ?? "") }
                if index < group.count - 1 {
                    Divider().background(Color(hex: 0xEEEEEE))
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white)
        .rounded(14)
    }
}

// ── Member row ────────────────────────────────────────────────────

private struct MemberRow: View {
    let member: FamilyMember
    let onUnlink: () -> Void

    var body: some View {
        let initials = (member.username ?? member.name ?? "?")
            .split(separator: " ").prefix(2)
            .map { $0.first.map { String($0).uppercased() } ?? "" }
            .joined()

        let role = member.roleId?.lowercased() ?? ""
        let isCaregiver = role == "caregiver" || role == "professional caregiver"
        let avatarColor = isCaregiver ? Color(hex: 0xE8E0FF) : Color(hex: 0xDEEBF5)
        let initialsColor = isCaregiver ? Color(hex: 0x6B4EFF) : Color(hex: 0x3B7FC4)

        let roleLabel: String = {
            switch member.roleId?.lowercased().trimmingCharacters(in: .whitespaces) {
            case "senior", "c8bac46a-8a46-5c17-a84b-59e3bc85fd62":
                return "Senior"
            case "family member", "58243a78-29ac-509b-92c8-98ee04ab8e99":
                return "Family Member"
            case "caregiver", "professional caregiver", "a48ad94d-0e41-59d1-9166-f70ae343f432":
                return "Caregiver"
            default:
                return member.roleId?.capitalizedFirst ?? ""
            }
        }()

        HStack {
            HStack(spacing: 14) {
                MemberAvatar(initials: initials, bgColor: avatarColor, textColor: initialsColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.username ?? member.name ?? "Unknown")
                        .font(appFont(15, .semibold)).foregroundStyle(TextDark)
                    Text({
                        var s = ""
                        if let email = member.email, email.isNotBlank { s += email }
                        if roleLabel.isNotBlank {
                            if !s.isEmpty { s += " · " }
                            s += roleLabel
                        }
                        return s
                    }())
                    .font(appFont(13)).foregroundStyle(TextGray)
                }
            }
            Spacer()
            Button(action: onUnlink) {
                Text("unlink")
                    .font(appFont(13, .medium))
                    .foregroundStyle(DangerRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .roundedBorder(DangerRed, 1, radius: 50)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
    }
}

private struct MemberAvatar: View {
    let initials: String
    let bgColor: Color
    let textColor: Color

    var body: some View {
        Circle()
            .fill(bgColor)
            .frame(width: 44, height: 44)
            .overlay(Text(initials).font(appFont(15, .bold)).foregroundStyle(textColor))
    }
}

// ─────────────────────────────────────────────────────────────────
//  INVITE DIALOG — pick role, generate code
// ─────────────────────────────────────────────────────────────────

struct InviteDialog: View {

    let isLoading: Bool
    let errorMsg: String?
    let onDismiss: () -> Void
    let onInvite: (String) -> Void

    private let roleOptions: [(String, String)] = [
        ("Family Member", "58243a78-29ac-509b-92c8-98ee04ab8e99"),
        ("Caregiver", "a48ad94d-0e41-59d1-9166-f70ae343f432")
    ]
    @State private var selectedRoleIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite Someone")
                .font(appFont(18, .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            Text("A 6-digit invite code will be generated. Share it with the person you want to invite.")
                .font(appFont(13))
                .foregroundStyle(TextGray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Role:").font(appFont(15, .bold))
                Menu {
                    ForEach(roleOptions.indices, id: \.self) { index in
                        Button(roleOptions[index].0) { selectedRoleIndex = index }
                    }
                } label: {
                    HStack {
                        Text(roleOptions[selectedRoleIndex].0).font(appFont(15)).foregroundStyle(TextDark)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(TextGray)
                    }
                    .padding(12)
                    .roundedBorder(BorderGray, 1, radius: 12)
                }
            }

            if let errorMsg, errorMsg.isNotBlank {
                Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button { onInvite(roleOptions[selectedRoleIndex].1) } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Generate Code").font(appFont(15, .semibold)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppGreen)
                    .rounded(50)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(appFont(15, .semibold)).foregroundStyle(Color(hex: 0x555555))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(SaveGray).rounded(50)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.height(340)])
    }
}

// ─────────────────────────────────────────────────────────────────
//  INVITE CODE DIALOG — show the generated code
// ─────────────────────────────────────────────────────────────────

struct InviteCodeDialog: View {

    let code: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppGreen)

            Spacer().frame(height: 12)
            Text("Invite Code").font(appFont(18, .bold))
            Spacer().frame(height: 8)
            Text("Share this code with the person you're inviting. It expires after one use.")
                .font(appFont(13))
                .foregroundStyle(TextGray)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            Text(chunked(code))
                .font(.system(size: 36 * AppFontSize.shared.scale, weight: .bold))
                .foregroundStyle(AppGreen)
                .tracking(4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(hex: 0xF0F7F4))
                .rounded(14)

            Spacer().frame(height: 24)

            Button(action: onDismiss) {
                Text("Done")
                    .font(appFont(16, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppGreen).rounded(50)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.height(400)])
    }

    /// Kotlin's `code.chunked(3).joinToString(" ")`
    private func chunked(_ s: String) -> String {
        var out: [String] = []
        var current = ""
        for ch in s {
            current.append(ch)
            if current.count == 3 { out.append(current); current = "" }
        }
        if !current.isEmpty { out.append(current) }
        return out.joined(separator: " ")
    }
}
