import Foundation
import Speech
import AVFoundation

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case notAvailable
    case audioEngineError
    case recognitionError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .audioEngineError:
            return "Audio engine failed to start."
        case .recognitionError(let error):
            return "Recognition error: \(error.localizedDescription)"
        }
    }
}

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var isRecording = false
    @Published var partialTranscription = ""
    @Published var finalTranscription: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechRecognitionError?
    @Published var audioLevel: Float = 0

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Recording

    func startRecording() async throws {
        guard isAuthorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        guard isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }

        // Cancel any existing task
        stopRecording()

        // Reset state
        partialTranscription = ""
        finalTranscription = nil
        error = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.audioEngineError
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud processing for better accuracy

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = .recognitionError(error)
                    self?.stopRecording()
                    return
                }

                if let result = result {
                    self?.partialTranscription = result.bestTranscription.formattedString

                    if result.isFinal {
                        self?.finalTranscription = result.bestTranscription.formattedString
                        self?.stopRecording()
                    }
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Cancel task if still running
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        audioLevel = 0

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancelRecording() {
        stopRecording()
        partialTranscription = ""
        finalTranscription = nil
    }

    // MARK: - Audio Level Calculation

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        // Convert to a more useful range (0-1)
        return min(1.0, average * 10)
    }

    // MARK: - Convenience

    func getTranscription() -> String {
        finalTranscription ?? partialTranscription
    }

    var hasTranscription: Bool {
        !partialTranscription.isEmpty || finalTranscription != nil
    }
}
