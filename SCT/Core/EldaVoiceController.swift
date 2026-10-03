import AVFoundation
import Foundation

@MainActor
final class EldaVoiceController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var status = "Listening..."
    @Published var isActive = false
    @Published var isMuted = false

    private let dictation = SpeechDictation()
    private let synthesizer = AVSpeechSynthesizer()
    private var onTranscript: ((String) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(onTranscript: @escaping (String) -> Void) {
        self.onTranscript = onTranscript
        isActive = true
        isMuted = false
        listen()
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            dictation.stop()
            status = "Microphone muted"
        } else {
            listen()
        }
    }

    func thinking() {
        dictation.stop()
        status = "Thinking..."
    }

    func speak(_ text: String) {
        guard isActive else { return }
        dictation.stop()
        status = "Speaking..."
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: String(text.prefix(4_000)))
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }

    func retry() {
        guard isActive else { return }
        isMuted = false
        listen()
    }

    func end() {
        dictation.stop()
        synthesizer.stopSpeaking(at: .immediate)
        isActive = false
        isMuted = false
        onTranscript = nil
    }

    private func listen() {
        guard isActive, !isMuted else { return }
        status = "Listening..."
        dictation.start { [weak self] text in
            guard let self, self.isActive, !text.isBlank else { return }
            self.status = "Thinking..."
            self.onTranscript?(text)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.listen() }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {}
}
