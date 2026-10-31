import AVFoundation
import SwiftUI
import Observation

@MainActor @Observable final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeID: ObjectIdentifier?
    private(set) var speaking = false
    private(set) var paused = false
    var error: String?

    override init() { super.init(); synthesizer.delegate = self }

    func speak(_ text: String, rate: Double) {
        stop()
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "zh-CN" }) else {
            error = "设备当前没有可用的普通话语音。您可以继续阅读文字，或在系统设置中添加语音。"
            return
        }
        error = nil
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = min(max(Float(rate), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        activeID = ObjectIdentifier(utterance)
        speaking = true; paused = false
        synthesizer.speak(utterance)
    }
    func togglePause() {
        if paused { if synthesizer.continueSpeaking() { paused = false } }
        else if synthesizer.pauseSpeaking(at: .immediate) { paused = true }
    }
    func stop() {
        activeID = nil
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false; paused = false
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finish(ObjectIdentifier(utterance)) }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { finish(ObjectIdentifier(utterance)) }
    private nonisolated func finish(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, activeID == id else { return }
            speaking = false; paused = false; activeID = nil
        }
    }
}

struct SpeechControls: View {
    @Environment(SpeechService.self) private var speech
    @Environment(Preferences.self) private var preferences
    let text: String
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button { speech.speak(text, rate: preferences.speechRate) } label: { Label("朗读", systemImage: "speaker.wave.2") }.buttonStyle(.bordered)
                if speech.speaking {
                    Button(speech.paused ? "继续" : "暂停") { speech.togglePause() }.buttonStyle(.bordered)
                    Button("停止") { speech.stop() }.buttonStyle(.bordered)
                }
            }
            if let error = speech.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
        }.onDisappear { speech.stop() }
    }
}
