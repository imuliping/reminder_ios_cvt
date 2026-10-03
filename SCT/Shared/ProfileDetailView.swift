//
//  ProfileDetailView.swift
//  Port of shared/ProfileDetailScreen.kt, plus EditProfileDialog /
//  AddContactDialog / TimeZoneDialog which lived in shared/ProfileScreen.kt.
//

import SwiftUI

struct ProfileDetailView: View {

    let onBack: () -> Void
    @StateObject private var vm = ProfileViewModel()

    @State private var showEditProfile = false
    @State private var showAddContact = false

    private var me: Me? { vm.meState.data }
    private var displayName: String { me?.username ?? TokenManager.getUsername() ?? "User" }
    private var displayEmail: String { me?.email ?? "" }
    private var displayAge: String { me?.age.map(String.init) ?? "" }
    private var displayPhone: String { me?.phone ?? "" }
    private var familyAccountId: String { TokenManager.getFamilyAccountId() ?? "—" }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: "Profile", onBack: onBack) {
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17))
                            .foregroundStyle(AppGreen)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 24)

                // ── Avatar ────────────────────────────────────────
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: 0xE8F5E9))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppGreen)
                        )
                    Text(displayName).font(appFont(20, .bold)).foregroundStyle(TextDark)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 24)

                // ── Personal Info ─────────────────────────────────
                sectionLabel("Personal Info")
                VStack(spacing: 0) {
                    infoRow("Full name", displayName.nonBlank ?? "—")
                    Divider().background(Color(hex: 0xF0F0F0))
                    infoRow("Email", displayEmail.nonBlank ?? "—")
                    Divider().background(Color(hex: 0xF0F0F0))
                    infoRow("Age", displayAge.nonBlank ?? "—")
                    Divider().background(Color(hex: 0xF0F0F0))
                    infoRow("Phone", displayPhone.nonBlank ?? "—")
                    Divider().background(Color(hex: 0xF0F0F0))
                    infoRow("Family ID", familyAccountId)
                }
                .padding(.horizontal, 20)
                .background(Color.white)
                .rounded(14)
                .padding(.horizontal, 16)

                if vm.meState.isLoading {
                    Spacer().frame(height: 8)
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(AppGreen)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 24)

                // ── Emergency Contacts ────────────────────────────
                HStack {
                    Text("Emergency Contact").font(appFont(13, .medium)).foregroundStyle(TextGray)
                    Spacer()
                    Button { showAddContact = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 13))
                            Text("Add").font(appFont(13, .medium))
                        }
                        .foregroundStyle(AppGreen)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                contactsCard

                Spacer().frame(height: 32)
            }
        }
        .background(Color(hex: 0xF7F7F7))
        .sheet(isPresented: $showEditProfile) {
            EditProfileDialog(
                currentUsername: me?.username ?? TokenManager.getUsername() ?? "",
                currentEmail: me?.email ?? "",
                currentAge: me?.age.map(String.init) ?? "",
                currentPhone: me?.phone ?? "",
                onDismiss: { showEditProfile = false },
                onSave: { username, email, age, phone in
                    guard let uid = TokenManager.getUserId() else { return }
                    vm.updateProfile(userId: uid, username: username, email: email, age: age, phone: phone)
                    showEditProfile = false
                }
            )
        }
        .sheet(isPresented: $showAddContact) {
            AddContactDialog(
                onDismiss: { showAddContact = false },
                onSave: { name, phone, relation in
                    vm.addEmergencyContact(name: name, phone: phone, relation: relation)
                    showAddContact = false
                }
            )
        }
    }

    @ViewBuilder
    private var contactsCard: some View {
        VStack(spacing: 0) {
            switch vm.contactsState {
            case .loading:
                ProgressView().tint(AppGreen).padding(20)
            case .success(let contacts):
                if contacts.isEmpty {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0xF5F5F5))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "plus").foregroundStyle(TextGray))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add emergency contact")
                                .font(appFont(15, .medium)).foregroundStyle(TextDark)
                            Text("Up to 5 contacts").font(appFont(12)).foregroundStyle(TextGray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    ForEach(Array(contacts.enumerated()), id: \.offset) { index, contact in
                        HStack {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: 0xFFF3E0))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 17))
                                            .foregroundStyle(Color(hex: 0xFF9800))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(appFont(15, .semibold)).foregroundStyle(TextDark)
                                    Text({
                                        var s = contact.phone
                                        if let relation = contact.relation, relation.isNotBlank {
                                            s += " · \(relation)"
                                        }
                                        return s
                                    }())
                                    .font(appFont(13)).foregroundStyle(TextGray)
                                }
                            }
                            Spacer()
                            Button {
                                guard let id = contact.contactId ?? contact.id else { return }
                                vm.deleteEmergencyContact(id: id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DangerRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 14)
                        if index < contacts.count - 1 {
                            Divider().background(Color(hex: 0xF0F0F0))
                        }
                    }
                }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .background(Color.white)
        .rounded(14)
        .padding(.horizontal, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(appFont(13, .medium)).foregroundStyle(TextGray)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(appFont(14)).foregroundStyle(TextGray)
            Spacer()
            Text(value).font(appFont(15, .semibold)).foregroundStyle(TextDark)
        }
        .padding(.vertical, 14)
    }
}

// ─────────────────────────────────────────────────────────────────
//  EDIT PROFILE DIALOG
// ─────────────────────────────────────────────────────────────────

struct EditProfileDialog: View {

    let currentUsername: String
    let currentEmail: String
    let currentAge: String
    var currentPhone: String = ""
    let onDismiss: () -> Void
    let onSave: (String?, String?, Int?, String?) -> Void

    @State private var username: String
    @State private var email: String
    @State private var age: String
    @State private var phone: String
    @State private var errorMsg = ""

    init(currentUsername: String, currentEmail: String, currentAge: String,
         currentPhone: String = "", onDismiss: @escaping () -> Void,
         onSave: @escaping (String?, String?, Int?, String?) -> Void) {
        self.currentUsername = currentUsername
        self.currentEmail = currentEmail
        self.currentAge = currentAge
        self.currentPhone = currentPhone
        self.onDismiss = onDismiss
        self.onSave = onSave
        _username = State(initialValue: currentUsername)
        _email = State(initialValue: currentEmail)
        _age = State(initialValue: currentAge)
        _phone = State(initialValue: currentPhone)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Profile")
                    .font(appFont(18, .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                labelled("Username") {
                    TextField("", text: $username).font(appFont(15))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .filledField()
                }
                labelled("Email") {
                    TextField("", text: $email).font(appFont(15))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .filledField()
                }
                labelled("Age") {
                    TextField("", text: $age).font(appFont(15))
                        .keyboardType(.numberPad)
                        .onChange(of: age) { _, v in age = v.digitsOnly }
                        .filledField()
                }
                labelled("Phone") {
                    TextField("+1 234 567 8900", text: $phone).font(appFont(15))
                        .keyboardType(.phonePad)
                        .filledField()
                }

                if errorMsg.isNotBlank {
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button {
                        if username.isBlank { errorMsg = "Username is required."; return }
                        onSave(
                            username.trimmingCharacters(in: .whitespaces) != currentUsername
                                ? username.trimmingCharacters(in: .whitespaces) : nil,
                            email.trimmingCharacters(in: .whitespaces) != currentEmail
                                ? email.trimmingCharacters(in: .whitespaces) : nil,
                            Int(age).flatMap { String($0) != currentAge ? $0 : nil },
                            phone.trimmingCharacters(in: .whitespaces).nonBlank
                        )
                    } label: {
                        Text("Save")
                            .font(appFont(16, .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppGreen).rounded(50)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(appFont(16, .semibold)).foregroundStyle(Color(hex: 0x555555))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(SaveGray).rounded(50)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func labelled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(appFont(15, .bold))
            content()
        }
    }
}

// ─────────────────────────────────────────────────────────────────
//  ADD CONTACT DIALOG
// ─────────────────────────────────────────────────────────────────

struct AddContactDialog: View {

    let onDismiss: () -> Void
    let onSave: (String, String, String?) -> Void

    @State private var name = ""
    @State private var phone = ""
    @State private var relation = ""
    @State private var errorMsg = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Emergency Contact")
                    .font(appFont(18, .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(appFont(15, .bold))
                    TextField("", text: $name).font(appFont(15)).filledField()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phone").font(appFont(15, .bold))
                    TextField("", text: $phone).font(appFont(15))
                        .keyboardType(.phonePad).filledField()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Relation").font(appFont(15, .bold))
                    TextField("e.g. Son, Daughter, Friend", text: $relation)
                        .font(appFont(15)).filledField()
                }

                if errorMsg.isNotBlank {
                    Text(errorMsg).font(appFont(13)).foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button {
                        if name.isBlank { errorMsg = "Name is required."; return }
                        if phone.isBlank { errorMsg = "Phone is required."; return }
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               phone.trimmingCharacters(in: .whitespaces),
                               relation.trimmingCharacters(in: .whitespaces).nonBlank)
                    } label: {
                        Text("Add")
                            .font(appFont(16, .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppGreen).rounded(50)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(appFont(16, .semibold)).foregroundStyle(Color(hex: 0x555555))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(SaveGray).rounded(50)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

// ─────────────────────────────────────────────────────────────────
//  TIME ZONE DIALOG
// ─────────────────────────────────────────────────────────────────

struct TimeZoneDialog: View {

    let currentTimeZone: String
    let onDismiss: () -> Void
    let onSave: (String) -> Void

    @State private var query = ""
    @State private var selected: String

    private let allZones = TimeZone.knownTimeZoneIdentifiers.sorted()

    init(currentTimeZone: String, onDismiss: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self.currentTimeZone = currentTimeZone
        self.onDismiss = onDismiss
        self.onSave = onSave
        _selected = State(initialValue: currentTimeZone)
    }

    private var filtered: [String] {
        query.isBlank ? allZones : allZones.filter { $0.range(of: query, options: .caseInsensitive) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Zone")
                .font(appFont(18, .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            TextField("Search time zones...", text: $query)
                .font(appFont(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .filledField()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered, id: \.self) { zone in
                        Button { selected = zone } label: {
                            HStack {
                                Text(zone)
                                    .font(appFont(14, zone == selected ? .bold : .regular))
                                    .foregroundStyle(zone == selected ? AppGreen : TextDark)
                                Spacer()
                                if zone == selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14)).foregroundStyle(AppGreen)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 280)

            HStack(spacing: 12) {
                Button { onSave(selected) } label: {
                    Text("Save")
                        .font(appFont(16, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(AppGreen).rounded(50)
                }
                .buttonStyle(.plain)
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(appFont(16, .semibold)).foregroundStyle(Color(hex: 0x555555))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(SaveGray).rounded(50)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}
