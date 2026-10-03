//
//  VoiceRecorder.swift
//  iOS replacement for the MediaRecorder usage in shared/AIChatScreen.kt —
//  records AAC-in-MPEG4 (.m4a) so the backend's /voice-action endpoint gets the
//  same audio/mp4 payload it got from Android.
//

import Foundation
import AVFoundation

@MainActor
final class VoiceRecorder: ObservableObject {

    @Published var isRecording = false

    private var recorder: AVAudioRecorder?
    private(set) var fileURL: URL?

    /// Mirrors the Android flow: request permission, then start.
    func start(onDenied: @escaping () -> Void = {}) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard granted else {
                    LogManager.logError("Microphone permission denied")
                    onDenied()
                    return
                }
                self?.beginRecording()
            }
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let name = "elda_voice_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            fileURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.record()
            self.recorder = recorder
            isRecording = true
        } catch {
            LogManager.logError("Could not start recording: \(error.localizedDescription)")
            isRecording = false
        }
    }

    /// Stops and returns the finished file, or nil if nothing was captured.
    @discardableResult
    func stop() -> URL? {
        guard isRecording else { return nil }
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return fileURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
    }
}
