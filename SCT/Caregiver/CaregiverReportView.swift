//
//  CaregiverReportView.swift
//  Port of caregiver/CaregiverReportScreen.kt — same report body as the family
//  screen, with the caregiver nav bar.
//

import SwiftUI

struct CaregiverReportView: View {

    let onBack: () -> Void
    let onNavigate: (String) -> Void
    @StateObject private var vm = ReportViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ReportHeader(
                weekStart: vm.selectedWeekStart,
                onBack: onBack,
                onPrevWeek: { vm.selectPreviousWeek() },
                onNextWeek: { vm.selectNextWeek() }
            )

            switch vm.reportState {
            case .loading:
                Spacer()
                ProgressView().tint(AppGreen)
                Spacer()
            case .error(let message):
                Spacer()
                ErrorRetry(message: message) { vm.loadReport() }
                Spacer()
            case .success(let data):
                ReportContent(data: data, seniorName: TokenManager.getSeniorName())
            default:
                Spacer()
            }

            CaregiverBottomNavBar(current: "home", onNavigate: onNavigate)
        }
        .background(Color.white)
    }
}
