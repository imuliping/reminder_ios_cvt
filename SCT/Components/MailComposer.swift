//
//  MailComposer.swift
//  iOS equivalent of LogManager.emailLog() on Android, which fired an
//  ACTION_SEND intent with the log file attached via FileProvider.
//

import SwiftUI
import MessageUI
import UIKit

struct MailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentName: String
    var onFinish: () -> Void = {}

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let attachmentData {
            vc.addAttachmentData(attachmentData, mimeType: "text/plain", fileName: attachmentName)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) { self.onFinish() }
        }
    }
}

/// "Contact Support" / "Send debug log" dialog — shown from the login, home,
/// family home, caregiver home and About Me screens on Android.
struct SupportLogSheet: View {
    let title: String
    let explanation: String
    let confirmLabel: String
    @Binding var isPresented: Bool

    @State private var recipient: String = LogManager.defaultEmail
    @State private var showMail = false
    @State private var mailUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(appFont(18, .bold))
            Text(explanation)
                .font(appFont(14))
                .foregroundStyle(TextGray)
                .fixedSize(horizontal: false, vertical: true)

            Text("Send log to").font(appFont(12)).foregroundStyle(TextGray)
            TextField("", text: $recipient)
                .font(appFont(15))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .roundedBorder(BorderGray, 1, radius: 12)

            if mailUnavailable {
                Text("No mail account is set up on this device. The log is at \(LogManager.getLogPath())")
                    .font(appFont(12))
                    .foregroundStyle(DangerRed)
            }

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .font(appFont(15))
                    .foregroundStyle(TextGray)
                Spacer()
                Button {
                    LogManager.logInfo("Support requested — sending to \(recipient)")
                    if MailComposer.canSendMail {
                        showMail = true
                    } else {
                        mailUnavailable = true
                    }
                } label: {
                    Text(confirmLabel)
                        .font(appFont(15, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppGreen)
                        .rounded(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .presentationDetents([.height(340)])
        .sheet(isPresented: $showMail) {
            MailComposer(
                recipient: recipient,
                subject: LogManager.subjectLine(),
                body: LogManager.logBody(),
                attachmentData: LogManager.logData(),
                attachmentName: "sct_debug.log"
            ) {
                isPresented = false
            }
        }
    }
}

/// The "Contact Support" text button that opens the sheet above.
struct ContactSupportButton: View {
    var label: String = "Contact Support"
    @Binding var showSheet: Bool

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "ant.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(TextGray)
                Text(label).font(appFont(13)).foregroundStyle(TextGray)
            }
        }
        .buttonStyle(.plain)
    }
}
