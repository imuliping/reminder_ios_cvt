# CONVERT.md — Android → iOS conversion playbook

How `reminder_ios_cvt` was produced from `reminder_android`, and how to re-sync
it when the Android code changes.

Read [§7 Re-sync workflow](#7-re-sync-workflow) first if you just want to update
the iOS app after an Android change. Everything above it is reference material
for *how* to translate a given construct.

---

## 0. Sync marker

**The iOS port currently reflects this Android commit:**

```
e9b80544278e6543fb4bf5e51f9db644c8c245ed   (e9b8054, 2026-10-02)
"Bump app version to 26.1002.01"
```

**Update this block every time you re-sync**, and record the new Android commit
hash. `git log <old>..<new>` against that hash is what drives the whole re-sync.

Baseline size at that commit: Android 74 Kotlin files / 18,485 lines →
iOS 63 Swift files / 16,636 lines.

---

## 1. Layout & toolchain

```
workspace_thirdparty/
├── reminder_android/     # source of truth  (git@imuliping.github.com:imuliping/reminder_android.git)
└── reminder_ios_cvt/     # this port
```

Built with Xcode 26.5 / Swift 6.3 compiler in **Swift 5 language mode**
(`SWIFT_VERSION = 5.0`). Deployment target iOS 17.0. Bundle id `com.example.sct`.

```bash
cd reminder_ios_cvt

# build
xcodebuild -project SCT.xcodeproj -scheme SCT -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# fast syntax/type check of a subset while iterating (seconds, not minutes)
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 5 SCT/Core/*.swift SCT/ViewModels/*.swift SCT/Components/*.swift

# install + launch on a booted sim
SIM=$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro' | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
xcrun simctl boot "$SIM"; xcrun simctl bootstatus "$SIM" -b
APP=$(xcodebuild -project SCT.xcodeproj -scheme SCT -sdk iphonesimulator \
  -destination "id=$SIM" -configuration Debug -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')
xcrun simctl install "$SIM" "$APP" && xcrun simctl launch "$SIM" com.example.sct
xcrun simctl io "$SIM" screenshot /tmp/shot.png
```

### The Xcode project needs no maintenance

`SCT.xcodeproj/project.pbxproj` uses an Xcode 16+
**`PBXFileSystemSynchronizedRootGroup`** pointed at `SCT/`. Any `.swift` file you
add under `SCT/` is compiled automatically — there is no file list to edit, and
**no pbxproj change is needed when adding, renaming or deleting source files.**

Touch `project.pbxproj` only to change build settings. `Info.plist` lives at the
repo root (deliberately *outside* `SCT/`) so the synchronized group doesn't try
to copy it in as a resource.

---

## 2. Architecture mapping

| Concern | Android | iOS |
|---|---|---|
| UI | Jetpack Compose | SwiftUI |
| State | `StateFlow<UiState<T>>` + `collectAsStateWithLifecycle()` | `@Published` on `@MainActor ObservableObject` + `@StateObject` |
| Navigation | single `currentScreen: String` + `when` | `Router.route: String` + `switch` in `AppNavigator` |
| Networking | Retrofit + OkHttp + Gson | `URLSession` + `async/await` + `Codable` |
| Result type | `Result<T>` via `safeCall {}` | `Result<T, Error>` via `safeCall {}` |
| Concurrency | coroutines, `viewModelScope.launch`, `async {}.awaitAll()` | Swift concurrency, `Task {}`, `async let`, `withTaskGroup` |
| Event bus | `MutableSharedFlow` (no replay) | Combine `PassthroughSubject` (no replay) |
| Local storage | `SharedPreferences("sct_prefs")` | `UserDefaults(suiteName: "sct_prefs")` |
| Push | Firebase Cloud Messaging | APNs + `UserNotifications` |
| Voice → text | `RecognizerIntent` | `SFSpeechRecognizer` + `AVAudioEngine` |
| Voice recording | `MediaRecorder` → m4a | `AVAudioRecorder` → AAC/m4a |
| Location | `FusedLocationProviderClient` | `CLLocationManager` (`kCLLocationAccuracyReduced`) |
| Log email | `ACTION_SEND` + `FileProvider` | `MFMailComposeViewController` |

---

## 3. File-by-file map

Keep this table current — it is the lookup you use during a re-sync.

### Core / infrastructure

| Android | iOS |
|---|---|
| `shared/Network.kt` — data classes | `Core/Models.swift` |
| `shared/Network.kt` — `ApiService` + `RetrofitClient` | `Core/APIService.swift` |
| `shared/Apprepository.kt` | `Core/AppRepository.swift` |
| `shared/TokenManager.kt` | `Core/TokenManager.swift` |
| `shared/LogManager.kt` | `Core/LogManager.swift` |
| `shared/NotificationBus.kt` | `Core/NotificationBus.swift` |
| `shared/Viewmodels.kt` (`UiState`) | `Core/UiState.swift` (also `RoleIds`, `todoLabelId`) |
| `shared/AppFontSize.kt` + `ui/theme/{Color,Theme,Type}.kt` | `Core/Theme.swift` |
| `shared/SharedComponents.kt` — date helpers | `Core/DateFormatting.swift` |
| `shared/SharedComponents.kt` — `getTaskIcon`, `filterJunk`, `StatusIndicator` | `Core/TaskIcon.swift` |
| `shared/SharedComponents.kt` — nav bars, `MessageEldaBar` | `Components/SharedComponents.swift` |
| `shared/EldaAvatar.kt`, `drawable-nodpi/elda_*` | `Shared/AIChatView.swift` — `EldaAvatar`, `Assets.xcassets/elda_*.imageset` |
| `mipmap-*/ic_launcher.png` | `Assets.xcassets/AppIcon.appiconset` |
| `shared/Offerhelpers.kt` | `Components/SharedComponents.swift` |
| `shared/SCTFirebaseMessagingServices.kt` | `Core/PushManager.swift` (+ `registerDeviceToken`/`unregisterDeviceToken` at the bottom of `Core/AppRepository.swift`) |
| `shared/MainActivity.kt` | `SCTApp.swift` + `AppNavigator.swift` |
| `shared/LinkedChangesScreen.kt` | `Shared/LinkedChangesView.swift` |
| `shared/AutoLogoutSettings.kt` + `shared/CheckInSettings.kt` | `Shared/SessionAndCheckInSettings.swift` |
| `shared/AIChatScreen.kt` — `ChatNavType`, `ChatMessage` | `Core/ChatTypes.swift` |
| the repeated `loadOffersForTasks` fan-out | `Core/OffersLoader.swift` |
| weather helpers at the top of `senior/HomeScreen.kt` | `Core/WeatherService.swift` |
| — (new, replaces `RecognizerIntent`) | `Core/SpeechDictation.swift` |
| — (new, replaces `MediaRecorder`) | `Core/VoiceRecorder.swift` |

### ViewModels

| Android | iOS |
|---|---|
| `shared/LoginViewModel.kt`, `SignupViewModel` + `ForgotPasswordViewModel` + `AcceptInviteViewModel` (inline in their screens) | `ViewModels/AuthViewModels.swift` |
| `shared/ProfileViewModel.kt` + `shared/RelativeAccountsViewModel.kt` | `ViewModels/ProfileViewModel.swift` |
| `shared/NotificationViewModel.kt` | `ViewModels/NotificationViewModel.swift` |
| `shared/SecurityViewModel.kt`, `GeneralSettingsViewModel.kt`, `PrivacySecurityViewModel.kt`, `NotificationSettingsViewModel.kt`, `ResetViewModel` (in `ResetScreen.kt`) | `ViewModels/SettingsViewModels.swift` |
| `shared/ShoppingListViewModel.kt` | `ViewModels/ShoppingListViewModel.swift` |
| `senior/ScheduleViewModel.kt` | `ViewModels/ScheduleViewModel.swift` |
| `MyDayViewModel` (in `senior/MyDayScreen.kt`) | `ViewModels/MyDayViewModel.swift` |
| `shared/AgentViewModel.kt` | `ViewModels/AgentViewModel.swift` |
| `GroupChatViewModel` + `OffersAssignedViewModel` + `OffersForMeViewModel` | `ViewModels/ChatAndOfferViewModels.swift` |
| `FamilyHomeViewModel`, `FamilyScheduleViewModel`, `SuperviseViewModel`, `ReportViewModel` | `ViewModels/FamilyViewModels.swift` |
| `CaregiverHomeViewModel`, `CaregiverAvailableTimeViewModel`, `CaregiverScheduleViewModel` | `ViewModels/CaregiverViewModels.swift` |

### Screens

| Android | iOS |
|---|---|
| `shared/LoginScreen.kt` | `Shared/LoginView.swift` |
| `shared/SignUpScreen.kt` | `Shared/SignupView.swift` |
| `shared/ForgotPasswordScreen.kt` | `Shared/ForgotPasswordView.swift` |
| `shared/AboutMeScreen.kt` | `Shared/AboutMeView.swift` |
| `shared/ProfileDetailScreen.kt` (+ dialogs from `ProfileScreen.kt`) | `Shared/ProfileDetailView.swift` |
| `shared/AcceptInviteScreen.kt` | `Shared/AcceptInviteView.swift` |
| `shared/SecurityScreen.kt` | `Shared/SecurityView.swift` |
| `shared/ResetScreen.kt` | `Shared/ResetView.swift` |
| `shared/GeneralSettingsScreen.kt` | `Shared/GeneralSettingsView.swift` |
| `shared/NotificationSettingScreen.kt` | `Shared/NotificationSettingsView.swift` |
| `shared/NotificationScreen.kt` + `family/FamilyNotificationScreen.kt` | `Shared/NotificationView.swift` (both screens + `NotificationCard`) |
| `shared/RelativeAccountsScreen.kt` | `Shared/RelativeAccountsView.swift` |
| `shared/ShoppingListScreen.kt` | `Shared/ShoppingListView.swift` |
| `shared/GroupChatScreen.kt` | `Shared/GroupChatView.swift` |
| `shared/AIChatScreen.kt` | `Shared/AIChatView.swift` |
| `shared/OffersAssignedScreen.kt` | `Shared/OffersAssignedView.swift` |
| `senior/HomeScreen.kt` | `Senior/SeniorHomeView.swift` |
| `senior/MyDayScreen.kt` | `Senior/MyDayView.swift` |
| `senior/ScheduleScreen.kt` | `Senior/ScheduleView.swift` |
| `family/FamilyHomeScreen.kt` | `Family/FamilyHomeView.swift` |
| `family/FamilyScheduleScreen.kt` | `Family/FamilyScheduleView.swift` |
| `family/FamilySuperviseScreen.kt` | `Family/SuperviseView.swift` |
| `family/FamilyOffersForMe.kt` | `Family/OffersForMeView.swift` |
| `family/FamilyReportScreen.kt` | `Family/FamilyReportView.swift` |
| `caregiver/CaregiverHomeScreen.kt` | `Caregiver/CaregiverHomeView.swift` |
| `caregiver/CaregiverScheduleScreen.kt` | `Caregiver/CaregiverScheduleView.swift` |
| `caregiver/CaregiverAvaliableTimeScreen.kt` | `Caregiver/CaregiverAvailableTimeView.swift` |
| `caregiver/CaregiverReportScreen.kt` | `Caregiver/CaregiverReportView.swift` |

### Extracted shared widgets

Compose declared these inside screen files; Swift pulls them out so several
screens can share them. **When an Android dialog/card changes, the edit usually
lands in one of these two files.**

| Android | iOS |
|---|---|
| `SeniorNewTaskDialog` (`senior/ScheduleScreen.kt`), `TodoTaskDialog` (`senior/ToDoTaskDialogue.kt`), `UnifiedTaskDialog` (`family/FamilyScheduleScreen.kt`), `CaregiverTaskDialog` (`caregiver/CaregiverScheduleScreen.kt`) | `Components/TaskDialogs.swift` |
| `ScheduleTaskCard`, `TodoTaskCard`, `FamilyScheduleTaskCard`, `FamilyTodoTaskCard`, recurring-edit scope dialog | `Components/TaskCards.swift` |
| `SDialogField`, `SRoundedField`, `SDateBox`, `STimeBox`, `SectionHeader`, `OverdueBadge` | `Components/SharedComponents.swift` |
| `LogManager.emailLog` UI + support dialogs | `Components/MailComposer.swift` |

### Deliberately not ported

- `shared/ProfileScreen.kt` → `ProfileScreen` composable is **dead code** on
  Android (nothing in `MainActivity` routes to it). Only its three dialogs
  (`EditProfileDialog`, `AddContactDialog`, `TimeZoneDialog`) are ported, into
  `Shared/ProfileDetailView.swift`.
- `shared/PrivacySecurityScreen.kt` → also unreachable. `PrivacySecurityViewModel`
  *is* ported (`ViewModels/SettingsViewModels.swift`) for parity, but no screen.
- `app/src/test`, `app/src/androidTest` → template tests, nothing to port.
- `google-services.json`, `AndroidManifest.xml`, `res/` → replaced by
  `Info.plist` + SF Symbols.

If one of these becomes reachable on Android, port it properly.

---

## 4. Translation cookbook

### 4.1 Models (`Network.kt` → `Models.swift`)

- Kotlin `data class Foo(val a: String?, …)` → `struct Foo: Codable`.
- Backend JSON is **camelCase** and Gson used field names verbatim, so **no
  `keyDecodingStrategy`** — property names must match the JSON exactly.
- `@SerializedName("_id")` → an explicit `CodingKeys` enum (see
  `NotificationInboxItem`).
- Gson omits nulls from request bodies; Swift's synthesized `encode(to:)` uses
  `encodeIfPresent` for optionals, so this matches for free. **Don't** add
  custom encoders that write nulls.
- Gson is lenient about a missing non-null field; `JSONDecoder` **throws**. If
  the backend starts omitting a field that is non-optional here, make it
  optional rather than adding a custom init.
- Kotlin extension functions on models (`Task.displayName()`, `Task.isOverdue()`)
  → computed properties on the struct.
- Model used in a `ForEach` / `.sheet(item:)` → add `Identifiable`.

### 4.2 Endpoints (`ApiService` → `APIService.swift`)

One Swift method per Retrofit method, same path, same parameter names:

| Retrofit | Swift |
|---|---|
| `@GET("x") suspend fun f(@Query("q") q: String?)` | `func f(q: String? = nil) async throws -> T { try await get("x", [("q", q)], as: T.self) }` |
| `@POST @Body` | `post(path, body: req, as: T.self)` |
| `@PUT @Body` | `put(path, body: req, as: T.self)` |
| `@DELETE` | `delete(path, as: T.self)` |
| `@HTTP(method="DELETE", hasBody=true)` | `delete(path, body: req, as:)` |
| `@FormUrlEncoded @POST` | `postForm(path, fields: [...], as:)` — **login only** |
| `@Multipart @POST` | `postMultipart(...)` — agent voice endpoints only |
| returns `String` | `as: String.self` — the decoder tolerates a bare JSON string *or* plain text |
| returns `Any` / `Unit` | `as: EmptyBody.self` |

`Query` is `[(String, Any?)]`; nil entries are dropped, matching Retrofit.
Bools render as `"true"`/`"false"`.

### 4.3 Repository (`Apprepository.kt` → `AppRepository.swift`)

- `object AppRepository` → `enum AppRepository` with `static func`s.
- `safeCall { }` is reproduced verbatim: `do { .success(try await call()) } catch { .failure(error) }`.
- **Preserve the defaulting logic exactly** — `subjectUserId` fallbacks
  (`subjectUserId ?? seniorUserId ?? userId`), the −30/+90 day windows,
  `limit = 30`, the `isSenior()` branch in `getTodayTasks()`. These are
  behavioural, not cosmetic.
- Kotlin `Result.fold/onSuccess/onFailure` are re-implemented as **async**
  extensions on `Result` (top of `AppRepository.swift`) so you can `await`
  inside the closures, like a suspending Kotlin lambda. **All call sites need
  `await`**, including chained ones:
  `await repo.x().onSuccess { … }.onFailure { … }`.
- `it.message` → `$0.message` (an `Error` extension in the same file).

### 4.4 ViewModels

```kotlin
class FooViewModel : ViewModel() {
    private val _state = MutableStateFlow<UiState<T>>(UiState.Idle)
    val state: StateFlow<UiState<T>> = _state
    init { load() }
    fun load() { viewModelScope.launch { _state.value = UiState.Loading; … } }
}
```
```swift
@MainActor final class FooViewModel: ObservableObject {
    @Published var state: UiState<T> = .idle
    init() { load() }
    func load() { Task { state = .loading; … } }
}
```

- `viewModelScope.launch { }` → `Task { }` (the VM is `@MainActor`, so UI
  updates are already on the right actor).
- `async { … }.awaitAll()` over a list → `withTaskGroup` (see
  `Core/OffersLoader.swift`) or `async let` for a fixed pair.
- `NotificationEventBus.x.collect { }` → `.sink { }` stored in
  `private var cancellables = Set<AnyCancellable>()`.
- `kotlinx.coroutines.delay(300)` → `try? await Task.sleep(nanoseconds: 300_000_000)`.
- Pattern used throughout: a public `func load()` that wraps a
  `private func loadAsync() async`, so other async code can `await loadAsync()`
  directly (Kotlin could just call the suspend fun).

### 4.5 Compose → SwiftUI

| Compose | SwiftUI |
|---|---|
| `Column` / `Row` / `Box` | `VStack` / `HStack` / `ZStack` |
| `LazyColumn` | `ScrollView { LazyVStack { } }` |
| `Modifier.weight(1f)` in a Row | `Spacer()` or `.frame(maxWidth: .infinity)` |
| `Spacer(Modifier.height(n))` | `Spacer().frame(height: n)` |
| `Modifier.clip(RoundedCornerShape(n))` | `.rounded(n)` (helper in `Theme.swift`) |
| `Modifier.border(w, c, shape)` | `.roundedBorder(c, w, radius:)` (helper) |
| `Color(0xFF7BAE8E)` | `Color(hex: 0x7BAE8E)` (helper) |
| `fontSize = 15.sp, fontWeight = Bold` | `.font(appFont(15, .bold))` — **always** `appFont`, never `.system(size:)` |
| `remember { mutableStateOf(x) }` | `@State private var x` |
| `LaunchedEffect(Unit) { }` | `.task { }` |
| `LaunchedEffect(key) { }` | `.task(id: key) { }` or `.onChange(of: key)` |
| `Dialog(onDismissRequest:)` | `.sheet(isPresented:)` / `.sheet(item:)` |
| `AlertDialog` with 1–3 buttons | `.alert` / `.confirmationDialog` |
| `ExposedDropdownMenuBox` | `Menu { } label: { }` (`PillMenu` + `PillMenuLabel` helpers) |
| `PullToRefreshBox` | `.refreshable { }` on the `ScrollView` |
| `Scaffold(bottomBar =)` | `VStack { content; BottomNavBar(...) }` |
| `Icons.Default.X` | nearest SF Symbol (see `Core/TaskIcon.swift` for the task-icon table) |
| `Switch` | `Toggle("", isOn:).labelsHidden().tint(AppGreen)` |
| `CircularProgressIndicator` | `ProgressView().tint(AppGreen)` |

### 4.6 Font scaling — important

Compose scaled the entire theme via `LocalDensity(fontScale =)`. SwiftUI has no
equivalent for fixed-size fonts, so **every explicit size must go through
`appFont(_:_:)`**, which multiplies by `AppFontSize.shared.scale`. `AppNavigator`
holds `@StateObject private var fontSize = AppFontSize.shared` so changing the
setting re-renders the tree. A raw `.font(.system(size: 15))` silently opts that
label out of the font-size preference — treat it as a bug.

### 4.7 Name collisions

| Kotlin | Swift | Why |
|---|---|---|
| `Task` | **`TaskItem`** | collides with Swift Concurrency's `Task` |
| `Label` | **`TaskLabel`** | collides with SwiftUI's `Label` |

Everything else keeps its Kotlin name. If a new Kotlin type collides with a
Swift/SwiftUI symbol, rename it and add a row here.

---

## 5. Gotchas hit during the first conversion

Each of these cost a build failure or a subtle behaviour change — check them
when you touch the relevant area.

1. **`@ViewBuilder` bodies can't hold statements.** `let f = DateFormatter(); f.dateFormat = …`
   inside `var body` → `error: type '()' cannot conform to 'View'`. Move the
   computation into a `private var x: String { }` computed property.
2. **Async `Result` helpers need `await` everywhere.** Missing one gives
   `expression is 'async' but is not marked with 'await'`. Chained calls need
   only one leading `await` for the whole expression.
3. **Don't declare both sync and async overloads** of `fold`/`onSuccess`/`onFailure`
   — overload resolution gets ambiguous. The port keeps **only** the async forms
   (a plain closure is still accepted where an `async` closure is expected).
4. **`CLLocationManagerDelegate` on a `@MainActor` class** warns about crossing
   actor boundaries. Fixed with `@preconcurrency CLLocationManagerDelegate`
   (callbacks arrive on the thread that created the manager = main).
5. **Two sheets in a row don't present.** The recurring-task flow (scope picker,
   then the edit dialog) is one `.sheet(item: $editingTask)` whose body switches
   on `editScope == nil`, mirroring Compose's two conditional composables.
6. **`Info.plist` must stay outside `SCT/`**, or the synchronized group copies it
   in as a resource.
7. **ATS.** The backend is plain HTTP; `Info.plist` has an
   `NSExceptionAllowsInsecureHTTPLoads` entry for `karyg.geofb.com`. If the host
   changes, update both `APIService.baseURLString` **and** the ATS domain key.
8. **Swift 5 language mode is deliberate.** Swift 6 strict concurrency would
   require a much larger rewrite of the ViewModel layer. Don't bump
   `SWIFT_VERSION` casually.

---

## 6. Platform substitutions that need human judgement

These have no mechanical translation; if the Android side changes here, think
rather than transliterate.

- **Push.** FCM is Android-only. `Core/PushManager.swift` registers an APNs
  token with `platform: "ios"` (Android sends `"android"`). The *routing* table
  (`type` → which bus event + which screen) is a verbatim port of
  `onMessageReceived()` — **if a new push `type` is added on Android, add it
  there too.** Note the backend must actually speak APNs for delivery to work.
- **Voice.** `MediaRecorder` → `AVAudioRecorder`, still AAC-in-MPEG4 `.m4a`
  posted as `audio/mp4`, so the `/voice-action` contract is unchanged.
- **Speech-to-text.** `RecognizerIntent` (a modal system activity) →
  `SFSpeechRecognizer` streaming with a start/stop mic button. Different UX by
  necessity; same resulting text appended to the chat input.
- **Location.** Coarse location → `kCLLocationAccuracyReduced`, same
  Toronto (43.6532, −79.3832) fallback, same 30-minute refresh loop.
- **Debug log email.** Intent chooser → `MFMailComposeViewController`, with a
  message pointing at the on-disk log path when no mail account is configured.
- **Navigation.** Kept as a single route string on purpose. There is no system
  back stack / swipe-back, exactly like the original. Don't "improve" this into
  `NavigationStack` unless the Android app does the same.

---

## 7. Re-sync workflow

When `reminder_android` changes:

### Step 1 — see what moved

```bash
cd reminder_android && git pull
git log --oneline <SYNC_MARKER_HASH>..HEAD
git diff --stat <SYNC_MARKER_HASH>..HEAD -- app/src/main
git diff <SYNC_MARKER_HASH>..HEAD -- app/src/main   # the actual review
```

### Step 2 — triage by layer, in this order

Work bottom-up; later layers depend on earlier ones.

1. **`Network.kt` changed?**
   - New/changed data class → `Core/Models.swift`.
   - New/changed endpoint → `Core/APIService.swift`.
   - Changed base URL → `APIService.baseURLString` **and** the ATS key in `Info.plist`.
2. **`Apprepository.kt` changed?** → `Core/AppRepository.swift`. Pay attention to
   defaulting/fallback logic, not just signatures.
3. **A ViewModel changed?** → find it in [§3](#3-file-by-file-map); several
   Kotlin VMs share one Swift file.
4. **A screen changed?** → the matching `*View.swift`. If the change is in a
   task dialog or task card, it is probably in `Components/TaskDialogs.swift` or
   `Components/TaskCards.swift` instead — those are shared across screens, so
   **check whether the Android change applies to one dialog or all four.**
5. **A new screen?** Add `<Name>View.swift` in the right folder **and** a `case`
   in `AppNavigator.swift` with the **exact** route string Android uses.
6. **New constants** (role UUIDs, label UUIDs, priority UUIDs) → `Core/UiState.swift`
   or the screen that owns them. Several are hard-coded in the Android source;
   grep for the literal before assuming.

### Step 3 — build and verify

```bash
# fast loop while editing
xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios17.0-simulator -swift-version 5 \
  SCT/Core/*.swift SCT/ViewModels/*.swift SCT/Components/*.swift

# full build — must end with ** BUILD SUCCEEDED ** and zero Swift warnings
xcodebuild -project SCT.xcodeproj -scheme SCT -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "error:|warning: .*\.swift|^\*\* " | sort -u
```

Then install + launch on the simulator (commands in [§1](#1-layout--toolchain))
and screenshot the screens you touched.

### Step 4 — update the sync marker

Set [§0](#0-sync-marker) to the new Android commit hash, and update the
[§3](#3-file-by-file-map) table if files were added, renamed or removed.

### Checklist

- [ ] Every changed Kotlin file located in the §3 map (or added to it)
- [ ] API paths, query names and body field names match Android **character for character**
- [ ] Route strings in `AppNavigator` match Android's `currentScreen` values exactly
- [ ] New explicit font sizes use `appFont(...)`
- [ ] New push `type` values added to `PushManager.handle(userInfo:)`
- [ ] `** BUILD SUCCEEDED **`, zero Swift warnings
- [ ] App launches on the simulator and the touched screens render
- [ ] §0 sync marker updated

---

## 8. Verification status & known gaps

Carry these forward; they are not bugs introduced by the port.

- ✅ Builds clean (Xcode 26.5, Swift 5 mode) — no errors, no Swift warnings.
- ✅ Installs and launches on iPhone 17 Pro / iOS 26.5; login screen renders and
  the notification permission prompt fires, as on Android.
- ⚠️ Authenticated API flows still require role-by-role simulator coverage.
  Login connectivity has been verified against `karyg.geofb.com:6682`.
- ⚠️ **Push delivery is unverified** and depends on the backend supporting APNs.
- ⚠️ Scripted UI interaction was unavailable (no accessibility permission for
  `osascript`), so verification stopped at "launches and renders".
