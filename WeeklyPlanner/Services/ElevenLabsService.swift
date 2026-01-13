import Foundation
import AVFoundation

enum ElevenLabsError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case audioPlaybackError(Error)
    case rateLimited
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "ElevenLabs API key not configured"
        case .invalidResponse:
            return "Invalid response from ElevenLabs"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .audioPlaybackError(let error):
            return "Audio playback error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please wait before trying again."
        case .quotaExceeded:
            return "ElevenLabs quota exceeded"
        }
    }
}

struct ElevenLabsVoice: Codable, Identifiable {
    let voiceId: String
    let name: String
    let previewUrl: String?
    let category: String?

    var id: String { voiceId }

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case name
        case previewUrl = "preview_url"
        case category
    }
}

struct VoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

@MainActor
class ElevenLabsService: ObservableObject {
    @Published var isSpeaking = false
    @Published var isProcessing = false
    @Published var selectedVoiceId: String = "21m00Tcm4TlvDq8ikWAM" // Rachel - default voice
    @Published var error: ElevenLabsError?
    @Published var availableVoices: [ElevenLabsVoice] = []

    private let baseURL = "https://api.elevenlabs.io/v1"
    private var audioPlayer: AVAudioPlayer?
    private let systemSpeechSynthesizer = AVSpeechSynthesizer()
    private let keychain = KeychainService.shared

    // MARK: - Configuration

    var isConfigured: Bool {
        keychain.hasElevenLabsKey
    }

    private var apiKey: String? {
        keychain.elevenLabsAPIKey
    }

    func configure(apiKey: String) {
        keychain.elevenLabsAPIKey = apiKey
    }

    // MARK: - Voice Selection

    func getAvailableVoices() async throws -> [ElevenLabsVoice] {
        guard let apiKey = apiKey else {
            throw ElevenLabsError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/voices")!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 30

        isProcessing = true
        defer { isProcessing = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ElevenLabsError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
                availableVoices = voicesResponse.voices
                return voicesResponse.voices
            case 429:
                throw ElevenLabsError.rateLimited
            default:
                throw ElevenLabsError.invalidResponse
            }
        } catch let error as ElevenLabsError {
            self.error = error
            throw error
        } catch {
            self.error = .networkError(error)
            throw ElevenLabsError.networkError(error)
        }
    }

    func setVoice(id: String) {
        selectedVoiceId = id
        keychain.elevenLabsVoiceId = id
    }

    // MARK: - Text to Speech

    func synthesizeSpeech(text: String) async throws -> Data {
        guard let apiKey = apiKey else {
            throw ElevenLabsError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/text-to-speech/\(selectedVoiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        isProcessing = true
        error = nil

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                isProcessing = false
                throw ElevenLabsError.invalidResponse
            }

            isProcessing = false

            switch httpResponse.statusCode {
            case 200:
                return data
            case 429:
                throw ElevenLabsError.rateLimited
            case 401:
                throw ElevenLabsError.noAPIKey
            default:
                throw ElevenLabsError.invalidResponse
            }
        } catch let error as ElevenLabsError {
            isProcessing = false
            self.error = error
            throw error
        } catch {
            isProcessing = false
            self.error = .networkError(error)
            throw ElevenLabsError.networkError(error)
        }
    }

    func playSpeech(_ audioData: Data) async throws {
        // Configure audio session for playback
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = AudioPlayerDelegate { [weak self] in
                Task { @MainActor in
                    self?.isSpeaking = false
                }
            }

            isSpeaking = true
            audioPlayer?.play()

            // Wait for playback to complete
            while audioPlayer?.isPlaying == true {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        } catch {
            isSpeaking = false
            self.error = .audioPlaybackError(error)
            throw ElevenLabsError.audioPlaybackError(error)
        }
    }

    func speakText(_ text: String) async throws {
        let audioData = try await synthesizeSpeech(text: text)
        try await playSpeech(audioData)
    }

    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSpeechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Fallback to System Voice

    func speakWithSystemVoice(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        systemSpeechSynthesizer.speak(utterance)
    }
}

// MARK: - Audio Player Delegate

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
