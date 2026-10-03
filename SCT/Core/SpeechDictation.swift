//
//  SpeechDictation.swift
//  iOS replacement for Android's RecognizerIntent.ACTION_RECOGNIZE_SPEECH,
//  used by the team-chat input to dictate a message.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechDictation: ObservableObject {

    @Published var isRecording = false
    @Published var partialText = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var onFinish: ((String) -> Void)?

    func start(onFinish: @escaping (String) -> Void) {
        self.onFinish = onFinish
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                LogManager.logError("Speech recognition not authorized (status \(status.rawValue))")
                return
            }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    LogManager.logError("Microphone permission denied for dictation")
                    return
                }
                Task { @MainActor in self?.beginSession() }
            }
        }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            LogManager.logError("Speech recognizer unavailable")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            partialText = ""
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        self.partialText = result.bestTranscription.formattedString
                        if result.isFinal { self.finish() }
                    }
                    if error != nil { self.finish() }
                }
            }
        } catch {
            LogManager.logError("Could not start dictation: \(error.localizedDescription)")
            stop()
        }
    }

    /// Called from the UI's stop button.
    func stop() {
        guard isRecording else { return }
        request?.endAudio()
        finish()
    }

    private func finish() {
        guard isRecording else { return }
        isRecording = false
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let text = partialText
        partialText = ""
        if text.isNotBlank { onFinish?(text) }
        onFinish = nil
    }
}
