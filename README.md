<h1 align="center">
  SCT 👵
  <br>
  Senior Care Tracker — iOS
  <br>
</h1>

<p align="center" style="font-size: 1.2rem;">A SwiftUI port of the <code>reminder_android</code> app (Kotlin + Jetpack Compose), talking to the same SCT REST backend.</p>

---

## What this is

`reminder_ios_cvt` is a screen-for-screen, endpoint-for-endpoint conversion of
[`reminder_android`](../reminder_android) to iOS. Every Compose screen, ViewModel,
repository method and Retrofit endpoint has a counterpart here; route strings,
API paths, request/response shapes, filtering rules and copy are preserved.

> **Updating this port after the Android app changes?** See
> **[CONVERT.md](CONVERT.md)** — it holds the sync marker (which Android commit
> this reflects), the full file-by-file map, the Kotlin→Swift translation
> cookbook, and the re-sync workflow.

| | Android | iOS |
|---|---|---|
| Language | Kotlin | Swift 5 |
| UI | Jetpack Compose | SwiftUI |
| Architecture | MVVM + `StateFlow` | MVVM + `ObservableObject` / `@Published` |
| Networking | Retrofit + OkHttp + Gson | `URLSession` + `async/await` + `Codable` |
| Concurrency | coroutines, `async {}.awaitAll()` | Swift concurrency, `withTaskGroup` |
| Event bus | `MutableSharedFlow` | Combine `PassthroughSubject` |
| Local storage | `SharedPreferences` | `UserDefaults` (suite `sct_prefs`) |
| Push | Firebase Cloud Messaging | APNs + `UserNotifications` |
| Voice → text | `RecognizerIntent` | `SFSpeechRecognizer` + `AVAudioEngine` |
| Voice recording | `MediaRecorder` (m4a) | `AVAudioRecorder` (AAC/m4a) |
| Location | `FusedLocationProviderClient` | `CLLocationManager` (reduced accuracy) |
| Log email | `ACTION_SEND` + `FileProvider` | `MFMailComposeViewController` |

Minimum deployment target **iOS 17.0**. Bundle id `com.example.sct`.

---

## Build & run

```bash
open SCT.xcodeproj          # then ⌘R
```

or from the command line:

```bash
xcodebuild -project SCT.xcodeproj -scheme SCT \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The project uses an Xcode 16+ *file-system synchronized group*, so new files
dropped into `SCT/` are picked up automatically — there is no file list to
maintain in `project.pbxproj`.

Code signing is disabled (`CODE_SIGNING_ALLOWED = NO`) so it builds for the
simulator with no team configured. Set your team in the target settings to run
on a device.

---

## Project structure

```
reminder_ios_cvt/
├── Info.plist                 # ATS exception + usage strings + remote-notification mode
├── SCT.xcodeproj/
└── SCT/
    ├── SCTApp.swift           # @main — the MainActivity.onCreate equivalent
    ├── AppNavigator.swift     # the `when (currentScreen)` route switch
    ├── Core/                  # models, API, repository, token/log managers, helpers
    ├── Components/            # shared widgets, task cards, the four task dialogs
    ├── ViewModels/            # one per Android ViewModel
    ├── Senior/ · Family/ · Caregiver/ · Shared/   # screens, mirroring the Kotlin packages
```

### Mapping at a glance

| Android | iOS |
|---|---|
| `shared/Network.kt` (data classes) | `Core/Models.swift` |
| `shared/Network.kt` (`ApiService`, `RetrofitClient`) | `Core/APIService.swift` |
| `shared/Apprepository.kt` | `Core/AppRepository.swift` |
| `shared/TokenManager.kt` | `Core/TokenManager.swift` |
| `shared/LogManager.kt` | `Core/LogManager.swift` |
| `shared/NotificationBus.kt` | `Core/NotificationBus.swift` |
| `shared/Viewmodels.kt` (`UiState`) | `Core/UiState.swift` |
| `shared/AppFontSize.kt`, `ui/theme/*` | `Core/Theme.swift` |
| `shared/SharedComponents.kt` | `Core/DateFormatting.swift`, `Core/TaskIcon.swift`, `Components/SharedComponents.swift` |
| `shared/Offerhelpers.kt` | `Components/SharedComponents.swift` |
| `shared/SCTFirebaseMessagingServices.kt` | `Core/PushManager.swift` |
| `shared/MainActivity.kt` | `SCTApp.swift` + `AppNavigator.swift` |
| `senior/ScheduleScreen.kt` dialogs, `senior/ToDoTaskDialogue.kt`, `family/…UnifiedTaskDialog`, `caregiver/…CaregiverTaskDialog` | `Components/TaskDialogs.swift` |
| task cards in `ScheduleScreen.kt` / `FamilyScheduleScreen.kt` | `Components/TaskCards.swift` |
| every `*Screen.kt` | matching `*View.swift` |

Two Kotlin type names collide with Swift/SwiftUI built-ins and were renamed:
`Task` → **`TaskItem`** (vs. Swift Concurrency's `Task`) and
`Label` → **`TaskLabel`** (vs. SwiftUI's `Label`). Everything else keeps its name.

---

## Backend

Same host as the Android client:

```
http://karyg.geofb.com:6682/
```

It is plain HTTP, so `Info.plist` carries an App Transport Security exception
for `karyg.geofb.com` (the counterpart of Android's `network_security_config.xml`).
To point at a different server, change `APIService.baseURLString` in
`Core/APIService.swift` and the ATS domain key in `Info.plist`.

Behaviour kept from the OkHttp stack: bearer token injected from `TokenManager`
on every request, 30-second timeouts, every request/response written to the
debug log, and `detail` pulled out of error bodies for user-facing messages.
Nil fields are omitted from request bodies, matching Gson's default.

---

## Permissions

| Purpose | Android | iOS (`Info.plist`) |
|---|---|---|
| Push notifications | `POST_NOTIFICATIONS` | requested at launch via `UNUserNotificationCenter`; `UIBackgroundModes: remote-notification` |
| Weather on the senior home screen | `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` |
| Elda voice messages | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` |
| Chat voice-to-text | `RecognizerIntent` | `NSSpeechRecognitionUsageDescription` |

---

## Platform differences worth knowing

- **Push.** FCM is Android-only. `PushManager` registers for APNs and posts the
  token to `POST /api/v1/notification-devices` with `platform: "ios"` (Android
  sent `"android"`). The *routing* logic — which bus event each push type fires
  and which screen it deep-links to — is ported verbatim from
  `SctFirebaseMessagingService.onMessageReceived()`. **The backend must be able
  to send APNs payloads for push to work**; registering an APNs token against a
  server that only speaks FCM will succeed but deliver nothing.
- **Font scaling.** Compose scaled the whole theme through
  `LocalDensity(fontScale:)`. SwiftUI has no equivalent for fixed-size fonts, so
  every explicit size goes through `appFont(_:_:)`, which multiplies by
  `AppFontSize.shared.scale`. The root view observes that object so a change
  re-renders the tree.
- **Navigation.** The Android app deliberately used one `currentScreen` string
  instead of a nav graph; `Router` keeps that model, so there is no system back
  stack or swipe-back — the same as the original.
- **Dialogs.** Compose `Dialog` becomes `.sheet`; simple confirms become
  `.alert` / `.confirmationDialog`.
- **Dead code.** `shared/ProfileScreen.kt`'s `ProfileScreen` and
  `shared/PrivacySecurityScreen.kt` are unreachable from the Android navigator.
  The dialogs that `ProfileScreen.kt` *did* export (`EditProfileDialog`,
  `AddContactDialog`, `TimeZoneDialog`) are ported into
  `Shared/ProfileDetailView.swift`; `PrivacySecurityViewModel` is ported in
  `ViewModels/SettingsViewModels.swift` for parity but, as on Android, nothing
  routes to it.

---

## Verification status

- ✅ Builds clean for the iOS simulator (Xcode 26.5, Swift 5 mode) — no errors, no Swift warnings.
- ✅ Installs and launches on an iPhone 17 Pro simulator (iOS 26.5); the login
  screen renders and the notification permission prompt fires as it does on Android.
- ⚠️ Authenticated API flows still require role-by-role simulator coverage.
  Login connectivity has been verified against `karyg.geofb.com:6682`.

---

## License

Educational and development purposes, same as the Android original.
