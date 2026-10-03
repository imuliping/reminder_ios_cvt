//
//  TokenManager.swift
//  Port of shared/TokenManager.kt — SharedPreferences becomes UserDefaults.
//

import Foundation

let appTimeZoneIdentifier = "America/Toronto"

enum TokenManager {

    private static let suiteName = "sct_prefs"

    private static let KEY_TOKEN              = "access_token"
    private static let KEY_USER_ID            = "user_id"
    private static let KEY_USERNAME           = "username"
    private static let KEY_FAMILY_ACCT_ID     = "family_account_id"
    private static let KEY_ROLE_ID            = "role_id"
    private static let KEY_SHOPPING_DETAIL_ID = "shopping_detail_id"
    private static let KEY_TIMEZONE           = "time_zone"
    private static let KEY_SENIOR_USER_ID     = "senior_user_id"
    private static let KEY_FONT_SIZE          = "font_size"
    private static let KEY_LANGUAGE           = "language"

    /// A dedicated suite keeps the app's keys namespaced the way
    /// getSharedPreferences("sct_prefs", …) did on Android.
    private static let prefs: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    static func initialize() {
        saveUserTimeZone(appTimeZoneIdentifier)
    }

    private static func string(_ key: String) -> String? { prefs.string(forKey: key) }
    private static func put(_ key: String, _ value: String) { prefs.set(value, forKey: key) }

    // ── Token ──────────────────────────────────────────────────────
    static func saveToken(_ token: String) { put(KEY_TOKEN, token) }
    static func getToken() -> String? { string(KEY_TOKEN) }
    static func clearToken() { prefs.removeObject(forKey: KEY_TOKEN) }

    // ── User ID ────────────────────────────────────────────────────
    static func saveUserId(_ id: String) { put(KEY_USER_ID, id) }
    static func getUserId() -> String? { string(KEY_USER_ID) }

    // ── Username ───────────────────────────────────────────────────
    static func saveUsername(_ name: String) { put(KEY_USERNAME, name) }
    static func getUsername() -> String? { string(KEY_USERNAME) }

    // ── Family Account ID ──────────────────────────────────────────
    static func saveFamilyAccountId(_ id: String) { put(KEY_FAMILY_ACCT_ID, id) }
    static func getFamilyAccountId() -> String? { string(KEY_FAMILY_ACCT_ID) }
    static func savePendingInvite(_ code: String) { put("pending_invite", code) }
    static func getPendingInvite() -> String { string("pending_invite") ?? "" }

    // ── Role ID ────────────────────────────────────────────────────
    static func saveRoleId(_ roleId: String) { put(KEY_ROLE_ID, roleId) }
    static func getRoleId() -> String? { string(KEY_ROLE_ID) }

    // ── Shopping Detail ID ─────────────────────────────────────────
    static func saveShoppingDetailId(_ id: String) { put(KEY_SHOPPING_DETAIL_ID, id) }
    static func getShoppingDetailId() -> String? { string(KEY_SHOPPING_DETAIL_ID) }

    // ── Timezone ───────────────────────────────────────────────────
    static func saveUserTimeZone(_ tz: String) { put(KEY_TIMEZONE, tz) }
    static func getUserTimeZone() -> String? { string(KEY_TIMEZONE) }
    static func saveLastSyncedTimeZone(_ tz: String) { put("last_synced_time_zone", tz) }
    static func getLastSyncedTimeZone() -> String? { string("last_synced_time_zone") }

    // ── Senior User ID ─────────────────────────────────────────────
    static func saveSeniorUserId(_ id: String) { put(KEY_SENIOR_USER_ID, id) }
    static func getSeniorUserId() -> String? { string(KEY_SENIOR_USER_ID) }
    static func saveSeniorName(_ name: String) { put("senior_name", name) }
    static func getSeniorName() -> String { string("senior_name") ?? "Senior" }

    // ── Agent Dialog ID ────────────────────────────────────────────
    static func saveDialogId(_ id: String) { put("agent_dialog_id", id) }
    static func getDialogId() -> String? { string("agent_dialog_id") }
    static func clearDialogId() { prefs.removeObject(forKey: "agent_dialog_id") }

    // ── Font Size ──────────────────────────────────────────────────
    static func saveFontSize(_ size: String) { put(KEY_FONT_SIZE, size) }
    static func getFontSize() -> String? { string(KEY_FONT_SIZE) ?? "medium" }

    // ── Language ───────────────────────────────────────────────────
    static func saveLanguage(_ lang: String) { put(KEY_LANGUAGE, lang) }
    static func getLanguage() -> String? { string(KEY_LANGUAGE) ?? "English (US)" }

    // ── Role helpers ───────────────────────────────────────────────
    private static var normalizedRole: String? {
        getRoleId()?.lowercased().trimmingCharacters(in: .whitespaces)
    }
    static func isSenior() -> Bool { normalizedRole == "senior" }
    static func isCoManager() -> Bool {
        ["trusted co-manager", "trusted co manager", "spouse"].contains(normalizedRole ?? "")
    }
    static func isFamilyMember() -> Bool { normalizedRole == "family member" || isCoManager() }
    static func isCaregiver() -> Bool {
        let r = normalizedRole
        return r == "caregiver" || r == "professional caregiver"
    }

    // ── Session ────────────────────────────────────────────────────
    static func isLoggedIn() -> Bool { getToken() != nil }
    static func saveAutoLogoutMinutes(_ value: Int) { prefs.set(value, forKey: "auto_logout_minutes") }
    static func getAutoLogoutMinutes() -> Int { prefs.integer(forKey: "auto_logout_minutes") }
    static func saveLastActivity(_ value: Date = Date()) { prefs.set(value.timeIntervalSince1970, forKey: "last_activity") }
    static func getLastActivity() -> Date? {
        let value = prefs.double(forKey: "last_activity")
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }
    static func clearSession() {
        for key in prefs.dictionaryRepresentation().keys {
            prefs.removeObject(forKey: key)
        }
    }

    static func saveDeviceId(_ deviceId: String) { put("device_id", deviceId) }
    static func getDeviceId() -> String? { string("device_id") }
    static func clearDeviceId() { prefs.removeObject(forKey: "device_id") }
}

/// Shared timezone resolution used by the model layer and the date formatters:
/// the backend stores datetimes already in the user's local timezone, not UTC.
func userTimeZone() -> TimeZone {
    if let tz = TokenManager.getUserTimeZone(), tz.isNotBlank,
       let zone = TimeZone(identifier: tz) {
        return zone
    }
    return TimeZone(identifier: appTimeZoneIdentifier) ?? .current
}
