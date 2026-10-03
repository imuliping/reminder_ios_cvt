import SwiftUI

struct LinkedChangesView: View {
    let onBack: () -> Void
    @State private var rows: [LinkedChange] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Suggested changes", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review each suggestion before confirming. Emergency contact changes require the senior's approval.")
                        .font(appFont(14))
                        .foregroundStyle(TextGray)

                    if isLoading { ProgressView().frame(maxWidth: .infinity) }
                    if let errorMessage {
                        Text(errorMessage).font(appFont(13)).foregroundStyle(DangerRed)
                    }
                    if !isLoading && rows.isEmpty {
                        Text("No suggested changes yet")
                            .font(appFont(15))
                            .foregroundStyle(TextGray)
                    }

                    Button("Refresh", action: load)
                        .buttonStyle(.bordered)

                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.title ?? "Suggested change").font(appFont(17, .bold))
                            Text("\(row.action.capitalizedFirst) · \(row.status)")
                                .font(appFont(13))
                                .foregroundStyle(TextGray)
                            ForEach((row.changes ?? [:]).keys.sorted(), id: \.self) { key in
                                if let value = row.changes?[key]?.stringValue {
                                    Text("\(key): \(value)").font(appFont(14))
                                }
                            }
                            Text("Reason: \(row.reason)").font(appFont(14))
                            if row.canReview && row.status == "pending" {
                                HStack {
                                    Button("Confirm change") { review(row, approve: true) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(AppGreen)
                                    Button("Reject") { review(row, approve: false) }
                                        .buttonStyle(.bordered)
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .rounded(14)
                    }
                }
                .padding(16)
            }
        }
        .background(AppBg)
        .task { load() }
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        Task {
            await AppRepository.getLinkedChanges().fold(
                onSuccess: {
                    rows = $0
                    isLoading = false
                },
                onFailure: {
                    errorMessage = $0.message
                    isLoading = false
                })
        }
    }

    private func review(_ row: LinkedChange, approve: Bool) {
        isLoading = true
        Task {
            await AppRepository.reviewLinkedChange(id: row.requestId, approve: approve).fold(
                onSuccess: { _ in load() },
                onFailure: {
                    errorMessage = $0.message
                    isLoading = false
                })
        }
    }
}
