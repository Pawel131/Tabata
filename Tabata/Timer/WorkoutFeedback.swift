import AudioToolbox
import AVFoundation
import UIKit

/// Audio, voice and haptic cues played during a workout.
final class WorkoutFeedback {
    static let soundKey = "feedback.sound"
    static let voiceKey = "feedback.voice"
    static let hapticsKey = "feedback.haptics"

    private let soundEnabled: Bool
    private let voiceEnabled: Bool
    private let hapticsEnabled: Bool

    private let synthesizer = AVSpeechSynthesizer()
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    init(defaults: UserDefaults = .standard) {
        soundEnabled = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        voiceEnabled = defaults.object(forKey: Self.voiceKey) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
    }

    func activate() {
        // Mix with (and briefly duck) any music the user is playing.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        impact.prepare()
        notification.prepare()
    }

    func deactivate() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func countdown(_ second: Int) {
        if soundEnabled {
            AudioServicesPlaySystemSound(1103) // Tink
        }
        if hapticsEnabled {
            impact.impactOccurred(intensity: 0.6)
        }
    }

    func phaseStarted(_ phase: Phase, config: WorkoutConfig) {
        if soundEnabled {
            AudioServicesPlaySystemSound(phase.kind == .work ? 1057 : 1104)
        }
        if hapticsEnabled {
            notification.notificationOccurred(phase.kind == .work ? .warning : .success)
        }
        speak(announcement(for: phase, config: config))
    }

    func finished() {
        if soundEnabled {
            AudioServicesPlaySystemSound(1025)
        }
        if hapticsEnabled {
            notification.notificationOccurred(.success)
        }
        speak("Workout complete. Great job!")
    }

    private func announcement(for phase: Phase, config: WorkoutConfig) -> String {
        switch phase.kind {
        case .prepare:
            return "Get ready"
        case .work:
            let isLast = phase.round == config.rounds && phase.set == config.sets
            if isLast { return "Last round. Work!" }
            return "Round \(phase.round). Work!"
        case .rest:
            return "Rest"
        case .setRest:
            return "Set \(phase.set) complete. Rest"
        }
    }

    private func speak(_ text: String) {
        guard voiceEnabled else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        synthesizer.speak(utterance)
    }
}
