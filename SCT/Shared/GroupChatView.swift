//
//  GroupChatView.swift
//  Port of shared/GroupChatScreen.kt. Android used RecognizerIntent for
//  voice-to-text; here that is SFSpeechRecognizer via SpeechRecognizer.swift.
//

import SwiftUI

struct GroupChatView: View {

    let onNavigate: (String) -> Void
    var isFamilyMember: Bool = false
    @StateObject private var vm = GroupChatViewModel()
    @StateObject private var speech = SpeechDictation()

    @State private var inputText = ""

    private var messages: [TeamChatMessage] { vm.messagesState.data ?? [] }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ───────────────────────────────────────────
            HStack {
                Button {
                    if TokenManager.isCaregiver() { onNavigate("caregiver_home") }
                    else if TokenManager.isFamilyMember() { onNavigate("family_home") }
                    else { onNavigate("home") }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(TextDark)
                        .padding(10)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Team Chat").font(appFont(18, .bold))
                Spacer()
                Button { vm.loadMessages() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                        .foregroundStyle(TextDark)
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)

            // ── Messages ──────────────────────────────────────────
            switch vm.messagesState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()

            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadMessages() }
                Spacer()

            default:
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(dayGroupedMessages.enumerated()), id: \.offset) { _, entry in
                                switch entry {
                                case .dayHeader(let key):
                                    Text(formatMessageDayHeader(key))
                                        .font(appFont(12, .medium))
                                        .foregroundStyle(TextGray)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: 0xEEEEEE))
                                        .rounded(50)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                case .message(let message):
                                    GroupMessageItem(message: message, isMe: vm.isMyMessage(message))
                                        .id(message.messageId)
                                }
                            }
                            Spacer().frame(height: 8).id("bottom")
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }

            // ── Input row ─────────────────────────────────────────
            HStack(spacing: 8) {
                TextField("Message the group...", text: $inputText, axis: .vertical)
                    .font(appFont(15))
                    .lineLimit(1...3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xF5F5F5))
                    .rounded(50)
                    .roundedBorder(BorderGray, 1, radius: 50)

                Button {
                    if speech.isRecording {
                        speech.stop()
                    } else {
                        speech.start { spokenText in
                            guard spokenText.isNotBlank else { return }
                            inputText = inputText.isBlank ? spokenText : "\(inputText) \(spokenText)"
                        }
                    }
                } label: {
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(speech.isRecording ? .white : TextDark)
                        .frame(width: 48, height: 48)
                        .background(speech.isRecording ? DangerRed : Color(hex: 0xE0E0E0))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    guard inputText.isNotBlank else { return }
                    vm.sendMessage(inputText)
                    inputText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(inputText.isBlank ? Color(.lightGray) : AppGreen)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)

            // ── Bottom nav — below the input row ──────────────────
            if TokenManager.isCaregiver() {
                CaregiverBottomNavBar(current: "chat", onNavigate: onNavigate)
            } else if TokenManager.isFamilyMember() {
                FamilyBottomNavBar(current: "chat", onNavigate: onNavigate)
            } else {
                BottomNavBar(current: "chat", onNavigate: onNavigate)
            }
        }
        .background(Color.white)
    }

    // Interleaves day headers with messages, like the Kotlin LazyColumn loop did.
    private enum ChatEntry {
        case dayHeader(String)
        case message(TeamChatMessage)
    }

    private var dayGroupedMessages: [ChatEntry] {
        var out: [ChatEntry] = []
        var lastDayKey = ""
        for message in messages {
            let ts = message.timestamp ?? message.createdAt ?? ""
            let dayKey = messageDayKey(ts)
            if dayKey != lastDayKey && dayKey.isNotBlank {
                lastDayKey = dayKey
                out.append(.dayHeader(dayKey))
            }
            out.append(.message(message))
        }
        return out
    }
}

struct GroupMessageItem: View {

    let message: TeamChatMessage
    let isMe: Bool

    var body: some View {
        let timeStr = formatMessageTime(message.timestamp ?? message.createdAt ?? "")

        if isMe {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Text(timeStr).font(appFont(13)).foregroundStyle(TextGray)
                    Text("You").font(appFont(14)).foregroundStyle(TextDark)
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(appFont(15))
                        .foregroundStyle(TextDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 80, alignment: .leading)
                        .background(Color(hex: 0xE8F0E9))
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 16, bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16, topTrailingRadius: 4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(message.senderDisplayName ?? message.senderName ?? "Member"):")
                        .font(appFont(14)).foregroundStyle(TextDark)
                    Text(timeStr).font(appFont(13)).foregroundStyle(TextGray)
                }
                if !message.content.isEmpty {
                    bubbleContent
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 80, alignment: .leading)
                        .background(Color(hex: 0xF0F0F0))
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16, topTrailingRadius: 16))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    /// "<Someone> completed the task of: <title>" bolds the part after the colon.
    @ViewBuilder
    private var bubbleContent: some View {
        if message.content.range(of: "completed the task of", options: .caseInsensitive) != nil {
            let parts = message.content.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count >= 2 {
                (Text(parts[0] + ":") + Text(parts[1]).bold())
                    .font(appFont(15))
                    .foregroundStyle(TextDark)
            } else {
                Text(message.content).font(appFont(15)).foregroundStyle(TextDark)
            }
        } else {
            Text(message.content).font(appFont(15)).foregroundStyle(TextDark)
        }
    }
}
