//
//  ChatTypes.swift
//  ChatNavType + ChatMessage, declared at the top of shared/AIChatScreen.kt on
//  Android. They live in Core here because AgentViewModel also needs them.
//

import Foundation

enum ChatNavType {
    case senior, family, caregiver
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
    let isUser: Bool
    var isConfirmation: Bool = false
    var confirmationQuestions: [String] = []
    var pendingIntentId: String = ""
    var pendingMessage: String = ""
    var cards: [ConversationCard] = []
}
