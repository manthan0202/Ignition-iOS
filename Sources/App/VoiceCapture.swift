import AVFoundation
import Foundation
import Speech

/// The user can stop speech and keep the last recognized words. Recording
/// completion and draft creation are separate actions; a cancel never silently
/// dismisses the text. Recognition may never return isFinal (offline/loss of
/// network), so a bounded fallback preserves the best available transcript.
@MainActor
final class VoiceCapture: ObservableObject {
    @Published var transcript = ""
    @Published private(set) var recording = false
    @Published private(set) var finalizing = false
    @Published var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audio = AVAudioEngine()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false
    private var generation = 0
    private var completion: CheckedContinuation<String, Never>?
    private var fallbackTask: Task<Void, Never>?
    /// Text that existed before this recording (typed, or an earlier dictation). A new recording appends to it
    /// instead of silently erasing it.
    private var baseText = ""
    /// Focus music is parked while the audio session is in record mode, then restored. Set by the owning view.
    weak var player: FocusAudioPlayer?

    // MARK: Nonisolated helpers
    // Closures created inside a @MainActor method inherit main-actor isolation. These callbacks are invoked
    // by the system on real-time audio / arbitrary queues, which is a known crash class on recent toolchains.
    // Building them in nonisolated statics keeps them off the main actor and hops back explicitly.
    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
    private nonisolated static func microphonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    private nonisolated static func installTap(on node: AVAudioInputNode, format: AVAudioFormat,
                                               request: SFSpeechAudioBufferRecognitionRequest) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }
    private nonisolated static func resultHandler(owner: VoiceCapture, generation: Int)
        -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        return { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            Task { @MainActor in
                owner?.handleResult(generation: generation, text: text, isFinal: isFinal, errorMessage: message)
            }
        }
    }
    private func handleResult(generation gen: Int, text: String?, isFinal: Bool, errorMessage: String?) {
        guard gen == generation else { return }
        if let text, !text.isEmpty {
            transcript = baseText.isEmpty ? text : baseText + " " + text
        }
        if finalizing && (isFinal || errorMessage != nil) {
            finishRecognition()
        } else if let errorMessage, !finalizing {
            errorText = errorMessage
        }
    }

    func begin() async {
        guard !recording && !finalizing else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "Speech recognition is unavailable. You can type instead."
            return
        }
        let authorization = await Self.speechAuthorization()
        guard authorization == .authorized else { errorText = "Speech permission denied. You can type instead."; return }
        let microphone = await Self.microphonePermission()
        guard microphone else { errorText = "Microphone permission denied. You can type instead."; return }
        do {
            errorText = nil
            baseText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            generation += 1
            let activeGeneration = generation
            player?.suspendForDictation()
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            let inputRequest = SFSpeechAudioBufferRecognitionRequest()
            inputRequest.shouldReportPartialResults = true
            // Prefer on-device recognition when the OS supports it; the audio then never leaves the phone.
            if recognizer.supportsOnDeviceRecognition { inputRequest.requiresOnDeviceRecognition = true }
            request = inputRequest
            let input = audio.inputNode
            if tapInstalled { input.removeTap(onBus: 0); tapInstalled = false }
            let format = input.outputFormat(forBus: 0)
            // A zero sample rate (no input hardware) makes installTap assert instead of throw.
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "IgnitionVoice", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No microphone input is available. You can type instead."])
            }
            Self.installTap(on: input, format: format, request: inputRequest)
            tapInstalled = true
            audio.prepare()
            try audio.start()
            recognition = recognizer.recognitionTask(with: inputRequest,
                resultHandler: Self.resultHandler(owner: self, generation: activeGeneration))
            recording = true
        } catch {
            errorText = error.localizedDescription
            discardAudio()
        }
    }

    func finish() async -> String {
        if finalizing { return transcript }
        guard recording else { return transcript }
        finalizing = true
        recording = false
        stopMicrophone()
        request?.endAudio()
        // Wait for the recognizer's actual final result; the timeout is a
        // fallback rather than an arbitrary delay used as if it were final.
        return await withCheckedContinuation { continuation in
            completion = continuation
            fallbackTask?.cancel()
            fallbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                self?.finishRecognition()
            }
        }
    }

    private func stopMicrophone() {
        if audio.isRunning { audio.stop() }
        if tapInstalled { audio.inputNode.removeTap(onBus: 0); tapInstalled = false }
    }

    private func finishRecognition() {
        fallbackTask?.cancel()
        fallbackTask = nil
        recognition?.cancel()
        recognition = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        player?.resumeAfterDictation()
        finalizing = false
        let result = transcript
        let waiting = completion
        completion = nil
        waiting?.resume(returning: result)
    }

    /// Navigation cleanup is not the same as finishing recognition. A view
    /// disappearing while finalizing MUST resume its pending continuation.
    func discardAudio(keepText: Bool = true) {
        generation += 1
        stopMicrophone()
        request?.endAudio()
        finishRecognition()
        recording = false
        if !keepText { transcript = "" }
    }
}
