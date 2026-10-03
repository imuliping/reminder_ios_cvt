//
//  OffersAssignedView.swift
//  Port of shared/OffersAssignedScreen.kt.
//

import SwiftUI

struct OffersAssignedView: View {

    let onBack: () -> Void
    @StateObject private var vm = OffersAssignedViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Offers Assigned", onBack: onBack)

            switch vm.offersState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()

            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadOffers() }
                Spacer()

            case .success(let offers):
                if offers.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No offers sent yet").font(appFont(15)).foregroundStyle(TextGray)
                        Text("Assign tasks to family members or caregivers\nto see them here.")
                            .font(appFont(13))
                            .foregroundStyle(TextGray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            Spacer().frame(height: 12)
                            ForEach(offers) { item in
                                OfferAssignedCard(item: item, userNames: vm.userNames)
                            }
                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

            default:
                Spacer()
            }
        }
        .background(Color(hex: 0xF7F7F7))
    }
}

// ── Card ──────────────────────────────────────────────────────────

private struct OfferAssignedCard: View {

    let item: OffersAssignedViewModel.OfferWithTask
    let userNames: [String: String]

    var body: some View {
        let offer = item.offer
        let task = item.task
        let status = offer.status?.uppercased() ?? "PENDING"

        let statusInfo: (String, Color, Color) = {
            switch status {
            case "ACCEPTED": return ("Accepted", Color(hex: 0xE8F5E9), Color(hex: 0x2E7D32))
            case "DECLINED": return ("Declined", Color(hex: 0xFFEBEE), DangerRed)
            default:         return ("Pending",  Color(hex: 0xFFF8E1), PendingGold)
            }
        }()

        let myId = TokenManager.getUserId()
        let assigneeName: String = {
            if let toUserId = offer.toUserId, toUserId != myId {
                return userNames[toUserId] ?? "User …\(String(toUserId.suffix(6)))"
            }
            return "Unknown"
        }()

        let timeStr = formatOfferTime(offer.proposedStart ?? offer.createdAt)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(taskName(task: task, offer: offer))
                    .font(appFont(16, .bold))
                    .foregroundStyle(TextDark)
                    .padding(.trailing, 8)
                Spacer()
                Text(statusInfo.0)
                    .font(appFont(12, .semibold))
                    .foregroundStyle(statusInfo.2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusInfo.1)
                    .rounded(50)
            }

            Spacer().frame(height: 4)
            Text("Assigned to \(assigneeName)").font(appFont(13)).foregroundStyle(TextGray)

            if timeStr.isNotEmpty {
                Spacer().frame(height: 6)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(TextGray)
                    Text(timeStr).font(appFont(12)).foregroundStyle(TextGray)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .rounded(14)
    }

    private func taskName(task: TaskItem?, offer: TaskAssignmentOffer) -> String {
        if let task { return task.displayName }
        if let msg = offer.message {
            if msg.contains("You've been assigned:") {
                let s = msg.components(separatedBy: "You've been assigned:").last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if s.isNotBlank { return s }
            }
            if msg.contains("Shopping:") {
                let s = msg.components(separatedBy: "Shopping:").last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if s.isNotBlank { return s }
            }
            if msg.contains("assigned") && msg.contains(":") {
                let s = msg.components(separatedBy: ":").dropFirst().joined(separator: ":")
                    .trimmingCharacters(in: .whitespaces)
                if s.isNotBlank { return s }
            }
        }
        return "Task \(offer.taskId.take(8))…"
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
