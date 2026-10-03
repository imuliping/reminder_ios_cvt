//
//  LogManager.swift
//  Port of shared/LogManager.kt. Writes to a rolling file in Documents and can
//  hand it to the mail composer (Android used an ACTION_SEND intent + FileProvider).
//

import Foundation
import UIKit

enum LogManager {

    private static let TAG       = "SCT_LOG"
    private static let LOG_FILE  = "sct_debug.log"
    private static let MAX_BYTES: UInt64 = 2 * 1024 * 1024

    private static var isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    static var defaultEmail: String = "kathleenwu301@gmail.com"

    private static var logFileURL: URL?
    private static let queue = DispatchQueue(label: "com.example.sct.logmanager")

    private static var dateFormat: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }

    /// Tracks the current screen for every log line.
    static var currentScreen: String = "unknown"

    // ── Init ──────────────────────────────────────────────────────
    static func initialize(emailRecipient: String = defaultEmail) {
        defaultEmail = emailRecipient
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(LOG_FILE)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64, size > MAX_BYTES {
            try? FileManager.default.removeItem(at: url)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        logFileURL = url
        installCrashHandler()
        writeLine("\(ts()) [SESSION START] App launched on \(UIDevice.current.model)")
    }

    // ── Crash handler ─────────────────────────────────────────────
    private static func installCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let first = exception.reason ?? exception.name.rawValue
            LogManager.writeLine("\(LogManager.ts()) [CRASH] \(LogManager.currentScreen) — \(exception.name.rawValue): \(first)")
        }
    }

    // ── Screen tracking ───────────────────────────────────────────
    static func setScreen(_ screen: String) { currentScreen = screen }

    // ── Core write ────────────────────────────────────────────────
    private static func ts() -> String { "[\(dateFormat.string(from: Date()))]" }

    private static func writeLine(_ line: String) {
        if isDebug { print("\(TAG): \(line)") }
        guard let url = logFileURL else { return }
        queue.async {
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }

    // ── Public log methods ────────────────────────────────────────
    static func logHttp(_ method: String, _ url: String) {
        writeLine("\(ts()) [HTTP] \(method) \(url)  \(currentScreen)")
    }

    static func logHttpResponse(_ code: Int, _ url: String) {
        writeLine("\(ts()) [HTTP] <-- \(code) \(url)  \(currentScreen)")
    }

    static func logHttpError(_ code: Int, _ url: String, _ error: String) {
        writeLine("\(ts()) [HTTP] <-- \(code) \(url)  \(currentScreen) ERROR: \(error)")
    }

    static func logError(_ message: String, _ error: Error? = nil) {
        let detail = error.map { " (\(type(of: $0)): \($0.localizedDescription))" } ?? ""
        writeLine("\(ts()) [ERROR] \(currentScreen) ERROR: \(message)\(detail)")
    }

    static func logInfo(_ message: String) {
        writeLine("\(ts()) [INFO] \(currentScreen) \(message)")
    }

    // ── Email log ─────────────────────────────────────────────────
    static func logBody() -> String {
        var out = "SCT Debug Log\n"
        out += "Device : \(UIDevice.current.model)  iOS: \(UIDevice.current.systemVersion)\n"
        out += "Sent   : \(dateFormat.string(from: Date()))\n"
        out += "────────────────────────────────────────\n\n"
        if let url = logFileURL, let contents = try? String(contentsOf: url, encoding: .utf8) {
            out += contents
        }
        return out
    }

    static func logData() -> Data? {
        guard let url = logFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func subjectLine() -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return "SCT Debug Log — \(f.string(from: Date()))"
    }

    static func getLogPath() -> String { logFileURL?.path ?? "Not initialized" }
}
