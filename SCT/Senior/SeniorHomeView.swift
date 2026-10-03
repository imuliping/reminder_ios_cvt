//
//  SeniorHomeView.swift
//  Port of senior/HomeScreen.kt.
//

import SwiftUI

struct SeniorHomeView: View {

    let onNavigate: (String) -> Void
    let onScheduleClick: () -> Void
    let onShopListClick: () -> Void
    let onNotificationClick: () -> Void
    let onProfileClick: () -> Void

    @StateObject private var location = CoarseLocationProvider()

    @State private var currentTime = ""
    @State private var currentDay = ""
    @State private var currentDate = ""
    @State private var weather: WeatherData?
    @State private var showSupportDialog = false

    private var username: String { TokenManager.getUsername() ?? "there" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────
                    HStack {
                        Button(action: onProfileClick) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(TextDark)
                                HStack(spacing: 0) {
                                    Text("Hi ").font(appFont(18))
                                    Text(username).font(appFont(18, .bold))
                                    Text(" !").font(appFont(18))
                                }
                                .foregroundStyle(TextDark)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button(action: onNotificationClick) {
                            Image(systemName: "bell")
                                .font(.system(size: 24))
                                .foregroundStyle(TextDark)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    // ── Clock + Weather banner (dynamic colour) ───
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: weatherCodeToGradient(weather?.code),
                                       startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Text(currentTime)
                                    .font(.system(size: 32 * AppFontSize.shared.scale, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer().frame(width: 12)
                                if let weather {
                                    Text(weather.emoji).font(appFont(24))
                                    Spacer().frame(width: 4)
                                    Text("\(weather.tempCelsius)°C")
                                        .font(appFont(22, .semibold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("☁").font(appFont(24))
                                }
                            }
                            Text(currentDay)
                                .font(.system(size: 30 * AppFontSize.shared.scale, weight: .bold))
                                .foregroundStyle(.white)
                            HStack(spacing: 8) {
                                Text(currentDate)
                                    .font(appFont(14))
                                    .foregroundStyle(.white.opacity(0.85))
                                if let weather, weather.description.isNotBlank {
                                    Text("·").font(appFont(14)).foregroundStyle(.white.opacity(0.6))
                                    Text(weather.description)
                                        .font(appFont(14))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(height: 180)

                    Spacer().frame(height: 20)

                    // ── Elda card ─────────────────────────────────
                    Button { onNavigate("aichat/home") } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("How can I help\nyou?")
                                    .font(appFont(15, .bold))
                                    .foregroundStyle(TextDark)
                                    .padding(10)
                                    .background(Color(hex: 0xEEEEEE))
                                    .clipShape(UnevenRoundedRectangle(
                                        topLeadingRadius: 12, bottomLeadingRadius: 4,
                                        bottomTrailingRadius: 12, topTrailingRadius: 12))
                                Spacer().frame(height: 10)
                                Text("Click Elda and just\nsay what you\nneed a reminder")
                                    .font(appFont(14))
                                    .foregroundStyle(TextGray)
                            }
                            Spacer()
                            EldaAvatar(size: 80)
                        }
                        .padding(16)
                        .background(Color.white)
                        .rounded(16)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    // ── Schedule + Shop list cards ────────────────
                    HStack(spacing: 16) {
                        Button(action: onScheduleClick) {
                            VStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        HStack(spacing: 6) {
                                            Circle().fill(TextDark).frame(width: 6, height: 6)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(TextDark)
                                                .frame(width: 28, height: 3)
                                        }
                                    }
                                }
                                Text("Schedule").font(appFont(14)).foregroundStyle(TextDark)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.white)
                            .rounded(16)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)

                        Button(action: onShopListClick) {
                            VStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(TextDark)
                                Text("Shop list").font(appFont(14)).foregroundStyle(TextDark)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.white)
                            .rounded(16)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 16)

                    Button { onNavigate("senior_offers_assigned") } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(TextDark)
                            Text("Offers Assigned")
                                .font(appFont(15, .medium))
                                .foregroundStyle(TextDark)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color.white)
                        .rounded(16)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 16)

                    ContactSupportButton(showSheet: $showSupportDialog)
                        .padding(.bottom, 8)
                }
            }
            .background(AppBg)

            BottomNavBar(current: "home", onNavigate: onNavigate)
        }
        .task {
            // Clock updater — Android pinned this to America/Toronto.
            let torontoTz = TimeZone(identifier: "America/Toronto") ?? .current
            let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"; timeFmt.timeZone = torontoTz
            let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEEE"; dayFmt.timeZone = torontoTz
            let dateFmt = DateFormatter(); dateFmt.dateFormat = "MMMM d, yyyy"; dateFmt.timeZone = torontoTz
            while !Task.isCancelled {
                let now = Date()
                currentTime = timeFmt.string(from: now)
                currentDay = dayFmt.string(from: now)
                currentDate = dateFmt.string(from: now)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .task {
            // Weather fetcher — GPS if permitted, silent fail if not.
            location.requestPermission()
            while !Task.isCancelled {
                if location.isAuthorized {
                    let fix = await location.currentLocation()
                    let lat = fix?.coordinate.latitude ?? 43.6532
                    let lon = fix?.coordinate.longitude ?? -79.3832
                    weather = await fetchWeather(lat: lat, lon: lon)
                } else {
                    weather = nil
                }
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            }
        }
        .sheet(isPresented: $showSupportDialog) {
            SupportLogSheet(
                title: "Contact Support",
                explanation: "Send us your debug log and we'll look into the issue.",
                confirmLabel: "Send Log",
                isPresented: $showSupportDialog
            )
        }
    }
}
