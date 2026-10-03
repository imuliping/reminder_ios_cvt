//
//  DateFormatting.swift
//  Port of the date/time helpers in shared/SharedComponents.kt plus the
//  shopping-list date helper from shared/ShoppingListScreen.kt.
//
//  Like the Android code these parse in the user's *saved* timezone, because
//  the backend returns local datetimes rather than UTC.
//

import Foundation

private func formatter(_ pattern: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = pattern
    f.timeZone = userTimeZone()
    return f
}

func parseChatDate(_ datetimeStr: String) -> Date? {
    let patterns = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "EEE MMM dd HH:mm:ss zzz yyyy"
    ]
    for pattern in patterns {
        if let date = formatter(pattern).date(from: datetimeStr) { return date }
    }

    // The backend sometimes appends fractional seconds / offsets; retry on the
    // leading 19 characters, which is what Android's `take(19)` relied on.
    if datetimeStr.count > 19 {
        return formatter("yyyy-MM-dd'T'HH:mm:ss").date(from: datetimeStr.take(19))
    }
    return nil
}

private func parseDatetimeLocal(_ datetimeStr: String) -> Date? {
    parseChatDate(datetimeStr)
}

/// "9:30 a.m."
func formatTimeOnly(_ datetimeStr: String) -> String {
    guard datetimeStr.isNotBlank, let date = parseDatetimeLocal(datetimeStr) else { return "" }
    return formatter("h:mm a").string(from: date)
        .replacingOccurrences(of: "AM", with: "a.m.")
        .replacingOccurrences(of: "PM", with: "p.m.")
}

/// "Mon, Jun 24 • 9:30 AM"
func formatNotificationTime(_ datetimeStr: String?) -> String {
    guard let datetimeStr, datetimeStr.isNotBlank else { return "" }
    guard let date = parseDatetimeLocal(datetimeStr) else { return datetimeStr }
    return formatter("EEE, MMM d • h:mm a").string(from: date)
}

/// ("24", "Mon") for the square date box on the task cards.
func formatDateBox(_ datetimeStr: String) -> (String, String) {
    guard datetimeStr.isNotBlank, let date = parseDatetimeLocal(datetimeStr) else {
        return ("--", "---")
    }
    return (formatter("d").string(from: date), formatter("EEE").string(from: date))
}

func formatDateShort(_ datetimeStr: String) -> String {
    let r = formatDateBox(datetimeStr)
    return "\(r.0)\n\(r.1)"
}

/// "9:30 a.m." for chat bubbles.
func formatMessageTime(_ datetimeStr: String) -> String {
    guard datetimeStr.isNotBlank else { return "" }
    guard let date = parseDatetimeLocal(datetimeStr) else { return datetimeStr }
    return formatter("h:mm a").string(from: date)
        .replacingOccurrences(of: "AM", with: "a.m.")
        .replacingOccurrences(of: "PM", with: "p.m.")
}

// ── Chat day grouping helpers ─────────────────────────────────────

/// "yyyy-MM-dd" in the user's timezone — used to detect day changes.
func messageDayKey(_ datetimeStr: String) -> String {
    guard datetimeStr.isNotBlank, let date = parseDatetimeLocal(datetimeStr) else { return "" }
    return formatter("yyyy-MM-dd").string(from: date)
}

/// "Today", "Yesterday", or "Mon, Jun 24, 2026".
func formatMessageDayHeader(_ dayKey: String) -> String {
    guard dayKey.isNotBlank else { return "" }
    guard let date = formatter("yyyy-MM-dd").date(from: dayKey) else { return dayKey }
    var cal = Calendar.current
    cal.timeZone = userTimeZone()
    if cal.isDateInToday(date) { return "Today" }
    if cal.isDateInYesterday(date) { return "Yesterday" }
    return formatter("EEE, MMM d, yyyy").string(from: date)
}

/// "Jun 24" — shopping list group headers.
func formatShoppingDate(_ dateStr: String) -> String {
    guard let date = formatter("yyyy-MM-dd").date(from: dateStr) else { return dateStr }
    return formatter("MMM d").string(from: date)
}

/// "MMM d, yyyy 'at' h:mm a" — used by the offer cards.
func formatOfferTime(_ raw: String?) -> String {
    guard let raw, raw.isNotBlank else { return "" }
    let clean = raw.take(19).replacingOccurrences(of: "T", with: " ")
    guard let date = formatter("yyyy-MM-dd HH:mm:ss").date(from: clean) else { return "" }
    return formatter("MMM d, yyyy 'at' h:mm a").string(from: date)
}

// ── "today"-style helpers that the ViewModels need ────────────────

/// SimpleDateFormat("yyyy-MM-dd").format(Date())
func todayString() -> String {
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

/// `Calendar.getInstance().add(DAY_OF_YEAR, offset)` then format as yyyy-MM-dd.
func dayOffsetString(_ offset: Int) -> String {
    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

/// SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").format(Date())
func nowDatetimeString() -> String {
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f.string(from: Date())
}

/// Parses an ISO-ish timestamp to epoch millis; used for the "updated within a day"
/// filter on the Offers Assigned screen.
func parseTimestampMillis(_ raw: String?) -> Double? {
    guard let raw else { return nil }
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    guard let d = f.date(from: raw.take(19)) else { return nil }
    return d.timeIntervalSince1970 * 1000
}
