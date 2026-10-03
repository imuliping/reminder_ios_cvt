//
//  OffersForMeView.swift
//  Port of family/FamilyOffersForMe.kt (the OffersForMeScreen composable).
//

import SwiftUI

struct OffersForMeView: View {

    let onBack: () -> Void
    @StateObject private var vm = OffersForMeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Offers For Me", onBack: onBack)

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
                        Text("No pending offers").font(appFont(15)).foregroundStyle(TextGray)
                        Text("Tasks assigned to you will appear here.")
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
                                OfferForMeCard(
                                    item: item,
                                    onAccept: { vm.acceptOffer(offerId: item.offer.offerId) },
                                    onDecline: { vm.declineOffer(offerId: item.offer.offerId) }
                                )
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

private struct OfferForMeCard: View {

    let item: OffersForMeViewModel.OfferForMe
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        let offer = item.offer
        let timeStr = formatOfferTime(offer.proposedStart ?? offer.createdAt)

        VStack(alignment: .leading, spacing: 0) {
            Text(item.taskTitle)
                .font(appFont(16, .bold))
                .foregroundStyle(TextDark)

            if timeStr.isNotEmpty {
                Spacer().frame(height: 6)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(TextGray)
                    Text(timeStr).font(appFont(12)).foregroundStyle(TextGray)
                }
            }

            if let message = offer.message, message.isNotBlank {
                Spacer().frame(height: 4)
                Text(message).font(appFont(13)).foregroundStyle(TextGray)
            }

            Spacer().frame(height: 12)

            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(appFont(14, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(AppGreen).rounded(50)
                }
                .buttonStyle(.plain)

                Button(action: onDecline) {
                    Text("Decline")
                        .font(appFont(14, .semibold)).foregroundStyle(DangerRed)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .roundedBorder(DangerRed, 1, radius: 50)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .rounded(14)
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
