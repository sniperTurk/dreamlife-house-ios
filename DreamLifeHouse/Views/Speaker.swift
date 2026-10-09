import AVFoundation

/// Reads furniture names aloud in a bright, child-like voice: first in the
/// app's language, then in the other one (Turkish ⇄ English), so children
/// learn the word in both languages. Uses on-device voices only.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()
    private var sessionReady = false

    func sayBoth(turkish: String, english: String, settings: PlayerSettings) {
        guard settings.soundEnabled else { return }
        prepareSession()
        synthesizer.stopSpeaking(at: .immediate)
        let pairs = L10n.isTurkish
            ? [(turkish, "tr-TR"), (english, "en-US")]
            : [(english, "en-US"), (turkish, "tr-TR")]
        for (index, pair) in pairs.enumerated() {
            let utterance = AVSpeechUtterance(string: pair.0)
            utterance.voice = AVSpeechSynthesisVoice(language: pair.1)
            utterance.pitchMultiplier = 1.6      // child-like voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.preUtteranceDelay = index == 0 ? 0 : 0.25
            synthesizer.speak(utterance)
        }
    }

    private func prepareSession() {
        guard !sessionReady else { return }
        // Play even with the ring/silent switch on; the in-game Sound toggle
        // turns speech off. Mix with other audio rather than stopping it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = true
    }
}
