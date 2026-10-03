//
//  SCTApp.swift
//  Entry point — the iOS counterpart of MainActivity.onCreate() in
//  shared/MainActivity.kt.
//

import SwiftUI

@main
struct SCTApp: App {

    /// Hosts the APNs / UserNotifications work that FirebaseMessagingService did.
    @UIApplicationDelegateAdaptor(PushManager.self) private var pushManager

    init() {
        TokenManager.initialize()
        LogManager.initialize(emailRecipient: "kathleenwu301@gmail.com")
        LogManager.logInfo("App started")
        _ = APIService.shared          // matches the eager `RetrofitClient.api` touch
    }

    var body: some Scene {
        WindowGroup {
            AppNavigator()
        }
    }
}
