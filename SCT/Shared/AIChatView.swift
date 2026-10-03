//
//  AIChatView.swift
//  Port of shared/AIChatScreen.kt — Elda chat, with the inactivity countdown,
//  Yes/No confirmation bubbles and voice recording.
//

import SwiftUI

private let EldaTeal = Color(hex: 0x286AC4)
private let EldaInk = Color(hex: 0x10254E)
private let EldaMint = Color(hex: 0xEAF3FF)
private let EldaMuted = Color(hex: 0x536A90)
private let EldaOutline = Color(hex: 0xD4E3FA)

struct AIChatView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    var navType: ChatNavType = .senior
    var sourceScreen: String = "home"       // which screen the user came from

    @StateObject private var vm = AgentViewModel()
    @StateObject private var voice = EldaVoiceController()

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var showHistory = false
    @State private var showAddMenu = false
    @State private var microphoneError: String?

    private var isLoading: Bool { vm.responseState.isLoading }
    private var avatarState: EldaAvatarState {
        if isLoading || voice.status.localizedCaseInsensitiveContains("thinking") { return .thinking }
        if voice.status.localizedCaseInsensitiveContains("speaking") { return .speaking }
        if voice.isActive { return .listening }
        return .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if voice.isActive {
                    Button(action: voice.end) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(EldaInk)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        vm.refreshHistory()
                        showHistory = true
                    } label: {
                        EldaAvatar(size: 44)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                VStack(spacing: 2) {
                    Text("Ask Elda")
                        .font(appFont(20, .bold))
                        .foregroundStyle(EldaInk)
                    if voice.isActive {
                        Text(vm.conversationTitle)
                            .font(appFont(12))
                            .foregroundStyle(EldaMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if voice.isActive {
                    Color.clear.frame(width: 48, height: 48)
                } else {
                    Button {
                        messages = []
                        inputText = ""
                        vm.newConversation()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(EldaTeal)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 70)
            .background(Color.white)

            Divider().background(Color(hex: 0xDCE8F8))

            if voice.isActive {
                voiceView
            } else {
                conversationView
            }

            eldaBottomBar
        }
        .background(Color.white)
        .sheet(isPresented: $showHistory) {
            EldaHistorySheet(
                vm: vm,
                onNew: {
                    messages = []
                    inputText = ""
                    vm.newConversation()
                    showHistory = false
                },
                onOpen: { dialog in
                    vm.openConversation(dialog) { loaded in messages = loaded }
                    showHistory = false
                }
            )
        }
        .confirmationDialog("Add to conversation", isPresented: $showAddMenu) {
            Button("Create a reminder") { inputText = "Remind me to " }
            Button("Check a message") { inputText = "Help me understand this message: " }
            Button("Check my schedule") { inputText = "What's on my schedule today?" }
            Button("Cancel", role: .cancel) {}
        }
        .task(id: sourceScreen) {
            vm.initialize(sourceScreen) { history in
                if !history.isEmpty { messages = history }
            }
        }
        .onChange(of: vm.responseState.isSuccess) { _, success in
            if success { handleResponseState() }
        }
        .onChange(of: vm.responseState.errorMessage) { _, message in
            guard let message else { return }
            messages.append(ChatMessage(sender: "Elda", text: message, isUser: false))
            if voice.isActive { voice.speak(message) }
            vm.resetState()
        }
        .onDisappear { voice.end() }
    }

    @ViewBuilder
    private var conversationView: some View {
        if messages.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 44)
                    Button(action: beginVoice) {
                        EldaAvatar(size: 180)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    Text("Talk to Elda")
                        .font(appFont(29, .bold))
                        .foregroundStyle(EldaInk)
                        .padding(.top, 16)
                    Text("Tap once to start")
                        .font(appFont(16))
                        .foregroundStyle(EldaMuted)
                    Text("What can I help you with?")
                        .font(appFont(17, .semibold))
                        .foregroundStyle(EldaInk)
                        .padding(.top, 26)

                    HStack(spacing: 10) {
                        EldaSuggestion(label: "Create a reminder", icon: "calendar") {
                            inputText = "Remind me to "
                        }
                        EldaSuggestion(label: "Check a message", icon: "envelope") {
                            inputText = "Help me understand this message: "
                        }
                    }
                    .padding(.top, 12)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        } else {
            Text(vm.conversationTitle)
                .font(appFont(16, .semibold))
                .foregroundStyle(EldaInk)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(messages) { msg in
                            ChatBubble(msg: msg, onAction: handleCardAction)
                                .id(msg.id)
                        }
                        if isLoading {
                            HStack(spacing: 12) {
                                EldaAvatar(state: .thinking, size: 30)
                                ProgressView().tint(EldaTeal)
                                Text("Elda is thinking...")
                                    .font(appFont(14))
                                    .foregroundStyle(EldaMuted)
                                Spacer()
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: isLoading) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }

        if let microphoneError {
            Text(microphoneError)
                .font(appFont(13))
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
        }
        composer
    }

    private var composer: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                TextField("Message Elda", text: $inputText, axis: .vertical)
                    .font(appFont(17))
                    .foregroundStyle(EldaInk)
                    .lineLimit(1...4)
                    .disabled(isLoading)

                HStack {
                    Button {
                        showAddMenu = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(appFont(14))
                            .foregroundStyle(EldaMuted)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    Spacer()

                    if inputText.isBlank {
                        Button(action: beginVoice) {
                            Label("Talk", systemImage: "mic.fill")
                                .font(appFont(14, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(EldaTeal)
                                .rounded(20)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    } else {
                        Button(action: sendDraft) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(EldaTeal)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .roundedBorder(EldaOutline, 1, radius: 25)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Text("Elda can make mistakes. Confirm important information.")
                .font(appFont(11))
                .foregroundStyle(EldaMuted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 7)
        }
    }

    private var voiceView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 52)
                EldaAvatar(state: avatarState, size: 180)
                Text(voice.status)
                    .font(appFont(24, .bold))
                    .foregroundStyle(EldaInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                Text(messages.last?.text ?? "Tell me what you need help with.")
                    .font(appFont(18))
                    .foregroundStyle(EldaMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 16)

                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Button {
                            voice.setMuted(!voice.isMuted)
                        } label: {
                            Image(systemName: voice.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 21))
                                .foregroundStyle(EldaInk)
                                .frame(width: 56, height: 56)
                                .background(EldaMint)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Text(voice.isMuted ? "Unmute" : "Mute")
                            .font(appFont(14))
                            .foregroundStyle(EldaMuted)
                    }
                    VStack(spacing: 8) {
                        Button(action: voice.end) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 21))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color(hex: 0xE45446))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Text("End voice")
                            .font(appFont(14))
                            .foregroundStyle(EldaMuted)
                    }
                }
                .padding(.top, 30)

                if voice.status.localizedCaseInsensitiveContains("try again") {
                    Button("Try again", action: voice.retry)
                        .foregroundStyle(EldaTeal)
                        .padding(.top, 12)
                }

                Button(action: voice.end) {
                    Label("View conversation", systemImage: "bubble.left.fill")
                        .font(appFont(16, .semibold))
                        .foregroundStyle(EldaInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(EldaMint)
                        .rounded(24)
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var eldaBottomBar: some View {
        let routes: [(String, String, String)] = {
            switch navType {
            case .senior:
                return [("myday", "calendar", "My Day"), ("", "mic.fill", "Ask Elda"),
                        ("notifications", "clock", "Activity"), ("chat", "bubble.left.fill", "Chat")]
            case .family:
                return [("family_schedule", "calendar", "My Day"), ("", "mic.fill", "Ask Elda"),
                        ("family_notifications", "clock", "Activity"), ("family_chat", "bubble.left.fill", "Chat")]
            case .caregiver:
                return [("caregiver_schedule", "calendar", "My Day"), ("", "mic.fill", "Ask Elda"),
                        ("caregiver_notifications", "clock", "Activity"), ("caregiver_chat", "bubble.left.fill", "Chat")]
            }
        }()

        return VStack(spacing: 0) {
            Divider().background(Color(hex: 0xDCE8F8))
            HStack(spacing: 0) {
                ForEach(Array(routes.enumerated()), id: \.offset) { index, item in
                    Button {
                        guard index != 1 else { return }
                        voice.end()
                        onNavigate(item.0)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.1).font(.system(size: 21))
                            Text(item.2).font(appFont(11))
                        }
                        .foregroundStyle(index == 1 ? EldaTeal : EldaMuted)
                        .frame(maxWidth: .infinity, minHeight: 66)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.white)
    }

    private func beginVoice() {
        microphoneError = nil
        voice.start { transcript in
            messages.append(ChatMessage(sender: "You", text: transcript, isUser: true))
            vm.sendMessage(transcript)
        }
    }

    private func sendDraft() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.isNotBlank, !isLoading else { return }
        messages.append(ChatMessage(sender: "You", text: message, isUser: true))
        inputText = ""
        vm.sendMessage(message)
    }

    private func handleCardAction(_ action: ConversationAction) {
        guard let value = action.value, value.isNotBlank else { return }
        switch action.kind {
        case "schedule":
            switch navType {
            case .senior: onNavigate("myday")
            case .family: onNavigate("family_schedule")
            case .caregiver: onNavigate("caregiver_schedule")
            }
        case "compose":
            inputText = value
        default:
            messages.append(ChatMessage(sender: "You", text: value, isUser: true))
            vm.sendMessage(value)
        }
    }

    private func handleResponseState() {
        guard case .success(let response) = vm.responseState else { return }
        switch response {
        case .reply(let text, let cards):
            messages.append(ChatMessage(sender: "Elda", text: text, isUser: false, cards: cards))
            if voice.isActive { voice.speak(text) }
        case .clarificationNeeded(let text, _):
            messages.append(ChatMessage(sender: "Elda", text: text, isUser: false))
            if voice.isActive { voice.speak(text) }
        case .confirmationNeeded(let text, let questions, let pendingIntentId, let pendingMessage):
            if text.isNotBlank {
                messages.append(ChatMessage(sender: "Elda", text: text, isUser: false))
            }
            messages.append(ChatMessage(
                sender: "Elda",
                text: questions.isEmpty ? "Would you like me to go ahead?"
                                        : questions.joined(separator: "\n"),
                isUser: false,
                isConfirmation: true,
                confirmationQuestions: questions,
                pendingIntentId: pendingIntentId,
                pendingMessage: pendingMessage
            ))
            if voice.isActive {
                voice.speak(questions.isEmpty ? text : questions.joined(separator: " "))
            }
        }
        vm.resetState()
    }
}

private struct EldaSuggestion: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(EldaTeal)
                Text(label)
                    .font(appFont(14))
                    .foregroundStyle(EldaInk)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Color.white)
            .roundedBorder(EldaOutline, 1, radius: 16)
        }
        .buttonStyle(.plain)
    }
}

private struct EldaHistorySheet: View {
    @ObservedObject var vm: AgentViewModel
    let onNew: () -> Void
    let onOpen: (AgentDialogSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [AgentDialogSummary] {
        query.isBlank ? vm.dialogs : vm.dialogs.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Button(action: onNew) {
                    Label("New conversation", systemImage: "plus")
                        .font(appFont(16, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(EldaTeal)
                        .rounded(14)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(EldaMuted)
                    TextField("Search conversations", text: $query)
                        .font(appFont(15))
                        .foregroundStyle(EldaInk)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .roundedBorder(EldaOutline, 1, radius: 16)

                if vm.loadingHistory {
                    ProgressView().tint(EldaTeal)
                } else if let error = vm.historyError {
                    VStack(spacing: 8) {
                        Text(error).font(appFont(14)).foregroundStyle(EldaMuted)
                        Button("Retry", action: vm.refreshHistory).foregroundStyle(EldaTeal)
                    }
                } else if filtered.isEmpty {
                    Text(query.isBlank ? "Your conversations will appear here." : "No matching conversations.")
                        .font(appFont(15))
                        .foregroundStyle(EldaMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List(filtered, id: \.dialogId) { dialog in
                        Button { onOpen(dialog) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bubble.left.fill")
                                    .foregroundStyle(EldaTeal)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dialog.title?.isBlank == false ? dialog.title! : "Conversation")
                                        .font(appFont(15))
                                        .foregroundStyle(EldaInk)
                                        .lineLimit(2)
                                    Text(conversationDate(dialog.updatedAt ?? dialog.createdAt))
                                        .font(appFont(12))
                                        .foregroundStyle(EldaMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(EldaMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.white)
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(EldaMuted)
                }
            }
        }
    }

    private func conversationDate(_ raw: String?) -> String {
        guard let raw, let date = parseChatDate(raw) else { return "Date unavailable" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = userTimeZone()
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        return formatter.string(from: date)
    }
}

// ── Bubbles ───────────────────────────────────────────────────────

struct ConfirmationBubble: View {
    let text: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            EldaAvatar()
            VStack(alignment: .leading, spacing: 12) {
                Text(text).font(appFont(16)).foregroundStyle(EldaInk)
                HStack(spacing: 8) {
                    Button(action: onConfirm) {
                        Text("Yes")
                            .font(appFont(13, .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(EldaTeal).rounded(50)
                    }
                    .buttonStyle(.plain)
                    Button(action: onCancel) {
                        Text("No")
                            .font(appFont(13, .semibold)).foregroundStyle(DangerRed)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .roundedBorder(DangerRed, 1, radius: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 280)
            .background(Color(hex: 0xF7FAFF))
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 16,
                bottomTrailingRadius: 16, topTrailingRadius: 16))
            Spacer(minLength: 0)
        }
    }
}

struct ChatBubble: View {
    let msg: ChatMessage
    var onAction: (ConversationAction) -> Void = { _ in }

    var body: some View {
        if msg.isUser {
            HStack {
                Spacer(minLength: 0)
                Text(msg.text)
                    .font(appFont(16))
                    .foregroundStyle(EldaInk)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: 310, alignment: .leading)
                    .background(EldaMint)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 20, bottomLeadingRadius: 20,
                        bottomTrailingRadius: 4, topTrailingRadius: 20))
            }
        } else {
            HStack(alignment: .top, spacing: 9) {
                EldaAvatar(size: 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elda")
                        .font(appFont(13))
                        .foregroundStyle(EldaTeal)
                    Text(msg.text)
                        .font(appFont(16))
                        .foregroundStyle(EldaInk)
                        .lineSpacing(3)
                        .frame(maxWidth: 310, alignment: .leading)
                    if msg.isConfirmation {
                        HStack(spacing: 8) {
                            Button("Yes, please.") {
                                onAction(ConversationAction(kind: "reply", label: "Yes", value: "Yes, please."))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(EldaTeal)
                            Button("Cancel") {
                                onAction(ConversationAction(kind: "reply", label: "Cancel", value: "No, cancel."))
                            }
                            .buttonStyle(.bordered)
                            .tint(EldaTeal)
                        }
                    }
                    ForEach(msg.cards) { card in
                        ConversationCardView(card: card, onAction: onAction)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct ConversationCardView: View {
    let card: ConversationCard
    let onAction: (ConversationAction) -> Void

    var body: some View {
        if card.version == 1,
           ["choice", "confirmation", "result", "list", "details"].contains(card.type ?? "") {
            VStack(alignment: .leading, spacing: 10) {
                if let title = card.title { Text(title).font(appFont(17, .bold)) }
                if let subtitle = card.subtitle {
                    Text(subtitle).font(appFont(14)).foregroundStyle(TextGray)
                }
                ForEach(Array((card.fields ?? []).enumerated()), id: \.offset) { _, field in
                    HStack(alignment: .top) {
                        Text(field.label ?? "").font(appFont(13)).foregroundStyle(TextGray)
                            .frame(width: 70, alignment: .leading)
                        Text(field.value ?? "").font(appFont(14))
                    }
                }
                ForEach(Array((card.actions ?? []).enumerated()), id: \.offset) { index, action in
                    if index == 0 {
                        Button(action.label ?? "Continue") { onAction(action) }
                            .buttonStyle(.borderedProminent)
                            .tint(AppGreen)
                    } else {
                        Button(action.label ?? "Continue") { onAction(action) }
                            .buttonStyle(.bordered)
                            .tint(AppGreen)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 280, alignment: .leading)
            .background(Color(hex: 0xFAFCFF))
            .roundedBorder(Color(hex: 0xD4E3FA), 1, radius: 16)
        }
    }
}

enum EldaAvatarState: String {
    case idle = "elda_idle"
    case listening = "elda_listening"
    case thinking = "elda_thinking"
    case speaking = "elda_speaking"
}

struct EldaAvatar: View {
    var state: EldaAvatarState = .idle
    var size: CGFloat = 32

    var body: some View {
        Image(state.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Elda")
    }
}
