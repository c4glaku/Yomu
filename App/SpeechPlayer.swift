import AVFoundation
import Observation

@MainActor @Observable
final class SpeechPlayer {
    private let synthesizer = AVSpeechSynthesizer()
    var error: String?
    func speak(_ text: String) {
        guard let voice = AVSpeechSynthesisVoice(language: "ja-JP") else {
            error = "A Japanese voice isn’t available on this device. Add a Japanese voice in the device’s Accessibility speech settings."
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.78
        synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
