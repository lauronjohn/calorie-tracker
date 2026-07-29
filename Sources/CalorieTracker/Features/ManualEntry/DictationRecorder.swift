import AVFoundation
import Foundation
import Speech

/// Merging dictated speech into whatever is already in the text field.
/// Pulled out as pure logic so it can be unit tested without a microphone.
enum DictationText {

    /// Appends a live transcript to text the user had already typed. Called on every
    /// partial result, so it must be idempotent for a given (base, transcript) pair —
    /// it always rebuilds from `base` rather than accumulating.
    static func merge(base: String, transcript: String) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedBase.isEmpty { return trimmedTranscript }
        if trimmedTranscript.isEmpty { return trimmedBase }
        return trimmedBase + " " + trimmedTranscript
    }
}

/// Live dictation via Apple's on-device speech recognition.
///
/// Chosen over sending audio to the AI provider: it is free, works offline when the
/// device supports on-device recognition, and produces text that feeds straight into
/// the existing `AnalysisInput.text` path — so voice entries go through exactly the
/// same prompt, schema and review screen as typed ones.
@MainActor
final class DictationRecorder: ObservableObject {

    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// True once the device has a recognizer for the current locale.
    var isSupported: Bool { recognizer != nil }

    // MARK: - Control

    func toggle() async {
        if isRecording {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !isRecording else { return }

        transcript = ""
        errorMessage = nil

        guard let recognizer else {
            errorMessage = "Speech recognition isn’t available for \(Locale.current.identifier)."
            return
        }
        guard await requestPermissions() else { return }
        guard recognizer.isAvailable else {
            errorMessage = "Speech recognition is temporarily unavailable. Try again in a moment."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Prefer on-device: no audio leaves the phone, and there is no network
            // round trip. Falls back to Apple's servers where unsupported, which is
            // also the more accurate path for unusual food and brand names.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            let input = audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }

                    if error != nil || result?.isFinal == true {
                        // A recognition error on a normal stop is routine (the audio
                        // stream just ended). Only surface it if nothing was heard.
                        if error != nil && self.transcript.isEmpty {
                            self.errorMessage = "Didn’t catch that — try again, a little closer to the mic."
                        }
                        self.teardown()
                    }
                }
            }
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            teardown()
        }
    }

    func stop() {
        guard isRecording else { return }
        // Ends the audio stream cleanly so the recognizer emits a final result; the
        // rest of the teardown happens in the recognition callback.
        request?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
    }

    // MARK: - Internals

    private func teardown() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Both permissions are needed: one to capture audio, one to transcribe it.
    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }

        switch speech {
        case .authorized:
            break
        case .denied:
            errorMessage = "Speech recognition is turned off for this app. Enable it in Settings → Privacy & Security → Speech Recognition."
            return false
        case .restricted:
            errorMessage = "Speech recognition is restricted on this device."
            return false
        case .notDetermined:
            errorMessage = "Speech recognition permission was not granted."
            return false
        @unknown default:
            errorMessage = "Speech recognition permission was not granted."
            return false
        }

        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }

        guard microphone else {
            errorMessage = "Microphone access is off for this app. Enable it in Settings → Privacy & Security → Microphone."
            return false
        }

        return true
    }
}
