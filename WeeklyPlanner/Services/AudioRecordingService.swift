import Foundation
import AVFoundation

enum AudioRecordingError: Error, LocalizedError {
    case notAuthorized
    case recordingFailed
    case fileError(Error)
    case audioSessionError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone access not authorized. Please enable in Settings."
        case .recordingFailed:
            return "Failed to start recording."
        case .fileError(let error):
            return "File error: \(error.localizedDescription)"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        }
    }
}

@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var error: AudioRecordingError?
    @Published var authorizationStatus: AVAudioSession.RecordPermission = .undetermined

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationStatus = AVAudioSession.sharedInstance().recordPermission
    }

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.checkAuthorizationStatus()
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .granted
    }

    // MARK: - Recording

    func startRecording(fileName: String? = nil) async throws -> URL {
        guard isAuthorized else {
            throw AudioRecordingError.notAuthorized
        }

        // Stop any existing recording
        stopRecording()

        // Generate file name
        let actualFileName = fileName ?? generateFileName()
        let url = getRecordingsDirectory().appendingPathComponent(actualFileName)

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw AudioRecordingError.audioSessionError(error)
        }

        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create recorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
        } catch {
            throw AudioRecordingError.fileError(error)
        }

        // Start recording
        guard audioRecorder?.record() == true else {
            throw AudioRecordingError.recordingFailed
        }

        currentRecordingURL = url
        isRecording = true
        recordingStartTime = Date()
        error = nil

        // Start timers for level and duration
        startTimers()

        return url
    }

    func stopRecording() -> URL? {
        stopTimers()

        audioRecorder?.stop()
        audioRecorder = nil

        isRecording = false
        recordingDuration = 0
        audioLevel = 0
        recordingStartTime = nil

        let url = currentRecordingURL
        currentRecordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false)

        return url
    }

    func cancelRecording() {
        let url = stopRecording()

        // Delete the file if it exists
        if let url = url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - File Management

    func getRecordingsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("VoiceRecordings", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }

        return recordingsPath
    }

    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func cleanupOldRecordings(olderThan days: Int) async {
        let directory = getRecordingsDirectory()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey]
            )

            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }

    func getRecordingsList() -> [URL] {
        let directory = getRecordingsDirectory()
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey]
            ).sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            return []
        }
    }

    // MARK: - Timers

    private func startTimers() {
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0
            return
        }

        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // Convert from dB (-160 to 0) to 0-1 range
        let normalizedLevel = max(0, (level + 60) / 60)
        audioLevel = normalizedLevel
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else {
            recordingDuration = 0
            return
        }
        recordingDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Helpers

    private func generateFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "\(timestamp)_\(UUID().uuidString.prefix(8)).m4a"
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = .recordingFailed
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .fileError(error)
            }
        }
    }
}
