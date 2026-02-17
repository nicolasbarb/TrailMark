import Foundation
import AVFoundation
import Dependencies

// MARK: - SpeechClient

struct SpeechClient: Sendable {
    var speak: @Sendable (String) async -> Void
    var stop: @Sendable () -> Void
    var configureAudioSession: @Sendable () throws -> Void
}

// MARK: - DependencyKey

extension SpeechClient: DependencyKey {
    static var liveValue: SpeechClient {
        let speaker = Speaker()

        return SpeechClient(
            speak: { message in
                await speaker.speak(message)
            },
            stop: {
                speaker.stop()
            },
            configureAudioSession: {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(
                    .playback,
                    mode: .voicePrompt,
                    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
                )
                try session.setActive(true)
            }
        )
    }

    static var testValue: SpeechClient {
        SpeechClient(
            speak: { _ in },
            stop: { },
            configureAudioSession: { }
        )
    }
}

extension DependencyValues {
    var speech: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}

// MARK: - Speaker

private final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    nonisolated(unsafe) private var _continuation: CheckedContinuation<Void, Never>?

    nonisolated private var continuation: CheckedContinuation<Void, Never>? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ message: String) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
            utterance.rate = 0.9 * AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0.1
            utterance.postUtteranceDelay = 0.2

            synthesizer.speak(utterance)
        }
    }

    nonisolated func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        continuation?.resume()
        continuation = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        continuation?.resume()
        continuation = nil
    }
}
