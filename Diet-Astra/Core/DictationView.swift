import SwiftUI
import Speech
import AVFoundation
import Observation

@MainActor @Observable
final class Dictation {
    var text = ""
    var error: String?
    var recording = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var tapped = false
    private var generation = UUID()
    var starting = false
    func start() async {
        guard !recording && !starting else { return }
        starting = true; error = nil
        let token = generation
        defer { if token == generation { starting = false } }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard token == generation && !Task.isCancelled else { return }
        guard status == .authorized, await AVAudioApplication.requestRecordPermission() else {
            error = "Microphone or speech access is off. Enable it in Settings, or type your meal instead."; return
        }
        guard token == generation && !Task.isCancelled else { return }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            error = "On-device dictation is unavailable for this language or device. You can type instead."; return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else { throw AppFailure.unavailable }
            try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(AVAudioPCMBuffer(copying: buffer)) }
            tapped = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.recording else { return }
                    if let result { self.text = result.bestTranscription.formattedString }
                    if result?.isFinal == true || error != nil { self.stop() }
                }
            }
            engine.prepare(); try engine.start(); recording = true
        } catch { stop(); self.error = "Could not start dictation. You can type your meal instead." }
    }
    func stop() {
        generation = UUID(); starting = false
        recording = false; engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct DictationView: View {
    let useText: (String) -> Void
    @State private var dictation = Dictation()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Dictation stays on this device. Review the text before sending it for meal interpretation.").font(.subheadline) }
                if let error = dictation.error { Text(error).foregroundStyle(.red) }
                TextEditor(text: $dictation.text).frame(minHeight: 120)
                Button(dictation.recording ? "Stop dictation" : "Start dictation") {
                    if dictation.recording { dictation.stop() } else { Task { await dictation.start() } }
                }
                .disabled(dictation.starting)
                Button("Use this text") { dictation.stop(); useText(dictation.text); dismiss() }
                    .disabled(dictation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.navigationTitle("Describe your meal")
                .toolbar { Button("Cancel") { dismiss() } }
        }.onDisappear { dictation.stop() }
    }
}
