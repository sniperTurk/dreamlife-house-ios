import AVFoundation

/// Reads names aloud for young learners. Turkish at a natural pace; English
/// words slowly and twice, so a child can hear and repeat them. Emoji are
/// stripped before speaking, and the best installed voice is used.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()
    private var sessionReady = false
    private var lastParts: [(String, String)] = []
    private var voices: [String: AVSpeechSynthesisVoice] = [:]

    func sayBoth(turkish: String, english: String, settings: PlayerSettings) {
        say(L10n.isTurkish ? [(turkish, "tr-TR"), (english, "en-US")] : [(english, "en-US"), (turkish, "tr-TR")], settings: settings)
    }

    func sayEnglish(_ text: String, settings: PlayerSettings) {
        say([(text, "en-US")], settings: settings)
    }

    /// Plays the last thing said again (tap on a speech bubble).
    func repeatLast(settings: PlayerSettings) {
        say(lastParts, settings: settings)
    }

    /// Speaks each (text, language) part in order, interrupting anything still playing.
    func say(_ parts: [(String, String)], settings: PlayerSettings) {
        guard settings.soundEnabled, !parts.isEmpty else { return }
        lastParts = parts
        prepareSession()
        synthesizer.stopSpeaking(at: .immediate)
        var first = true
        for part in parts {
            let text = Self.clean(part.0)
            guard !text.isEmpty else { continue }
            let english = part.1.hasPrefix("en")
            // A single word or short name is a vocabulary word: say it twice.
            let isWord = text.split(separator: " ").count <= 3 && !text.contains(".") && !text.contains(",")
            let repeats = english && isWord ? 2 : 1
            for r in 0..<repeats {
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = voice(for: part.1)
                utterance.pitchMultiplier = 1.12          // a little brighter, still clear
                // AVSpeechUtteranceDefaultSpeechRate is 0.5.
                utterance.rate = english ? (isWord ? (r == 0 ? 0.34 : 0.38) : 0.40) : 0.46
                utterance.preUtteranceDelay = first ? 0 : 0.45
                synthesizer.speak(utterance)
                first = false
            }
        }
    }

    /// True when a higher-quality (Enhanced/Premium) English voice is installed.
    var hasEnhancedEnglishVoice: Bool {
        voice(for: "en-US").quality != .default
    }

    private func voice(for language: String) -> AVSpeechSynthesisVoice? {
        if let cached = voices[language] { return cached }
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == language && !$0.voiceTraits.contains(.isNoveltyVoice)
        }
        let best = candidates.max { a, b in
            if a.quality != b.quality { return a.quality.rawValue < b.quality.rawValue }
            // Prefer the well-known clear voices at equal quality.
            return Self.preferred.firstIndex(of: a.name) ?? 99 > Self.preferred.firstIndex(of: b.name) ?? 99
        } ?? AVSpeechSynthesisVoice(language: language)
        if let best { voices[language] = best }
        return best
    }

    private static let preferred = ["Samantha", "Ava", "Nicky", "Yelda", "Zoe", "Allison", "Susan"]

    /// Removes emoji and separators so the voice does not read them out.
    static func clean(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { s in
            !(s.properties.isEmojiPresentation || (s.properties.isEmoji && s.value > 0x238C) || s.value == 0xFE0F || s.value == 0x200D)
        }
        return String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: "·", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
