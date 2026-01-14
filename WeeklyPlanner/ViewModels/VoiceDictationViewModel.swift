import Foundation
import Combine

@MainActor
class VoiceDictationViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isRecording = false
    @Published var partialTranscription = ""
    @Published var isProcessing = false
    @Published var currentReminder: VoiceReminder?
    @Published var error: String?
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0

    // Context for the recording
    @Published var currentClient: Client?
    @Published var currentSession: Appointment?

    // Services
    private let speechService = SpeechRecognitionService()
    private let audioService = AudioRecordingService()
    private let aiService = AIProcessingService()

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind speech service state
        speechService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        speechService.$partialTranscription
            .receive(on: DispatchQueue.main)
            .assign(to: &$partialTranscription)

        speechService.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        // Bind audio service duration
        audioService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        // Combine errors
        speechService.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    var isAuthorized: Bool {
        speechService.isAuthorized && audioService.isAuthorized
    }

    func requestAuthorization() async -> Bool {
        let speechAuth = await speechService.requestAuthorization()
        let audioAuth = await audioService.requestAuthorization()
        return speechAuth && audioAuth
    }

    // MARK: - Recording

    func startDictation() async {
        error = nil
        currentReminder = nil

        do {
            // Start audio recording (for backup)
            _ = try await audioService.startRecording()

            // Start speech recognition
            try await speechService.startRecording()
        } catch {
            self.error = error.localizedDescription
            _ = await stopDictation()
        }
    }

    func stopDictation() async -> VoiceReminder? {
        // Stop speech recognition
        speechService.stopRecording()

        // Stop audio recording
        let audioURL = audioService.stopRecording()

        // Get the transcription
        let transcription = speechService.getTranscription()

        guard !transcription.isEmpty else {
            return nil
        }

        // Create the reminder
        let reminder = VoiceReminder(
            clientId: currentClient?.id,
            sessionId: currentSession?.id,
            transcription: transcription,
            audioFileURL: audioURL?.path,
            clientName: currentClient?.name
        )

        currentReminder = reminder
        return reminder
    }

    func cancelDictation() {
        speechService.cancelRecording()
        audioService.cancelRecording()
        partialTranscription = ""
        currentReminder = nil
    }

    // MARK: - AI Processing

    func processAndSave(priorityOverride: ReminderPriority? = nil, categoryOverride: ReminderCategory? = nil) async throws -> VoiceReminder {
        guard var reminder = currentReminder else {
            throw NSError(domain: "VoiceDictation", code: 1, userInfo: [NSLocalizedDescriptionKey: "No reminder to process"])
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Process with AI
            let processed = try await aiService.processReminder(
                reminder.transcription,
                clientContext: currentClient
            )

            // Update reminder with AI results
            reminder.isProcessedByAI = true
            reminder.aiExtractedFollowUps = processed.extractedFollowUps
            reminder.aiSuggestedCategory = processed.suggestedCategory
            reminder.priority = processed.suggestedPriority
            reminder.status = .ready
            reminder.processedAt = Date()

            if let priorityOverride {
                reminder.priority = priorityOverride
            }
            if let categoryOverride {
                reminder.aiSuggestedCategory = categoryOverride
            }

            currentReminder = reminder

            // Save locally
            try saveReminderLocally(reminder)

            return reminder
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func saveWithoutProcessing(priorityOverride: ReminderPriority? = nil, categoryOverride: ReminderCategory? = nil) throws -> VoiceReminder {
        guard var reminder = currentReminder else {
            throw NSError(domain: "VoiceDictation", code: 1, userInfo: [NSLocalizedDescriptionKey: "No reminder to save"])
        }

        if let priorityOverride {
            reminder.priority = priorityOverride
        }
        if let categoryOverride {
            reminder.aiSuggestedCategory = categoryOverride
        }

        reminder.status = .transcribed
        currentReminder = reminder

        try saveReminderLocally(reminder)
        return reminder
    }

    // MARK: - Local Storage

    private func saveReminderLocally(_ reminder: VoiceReminder) throws {
        var reminders = loadLocalReminders()
        reminders.append(reminder)

        let url = getRemindersFileURL()
        let data = try JSONEncoder().encode(reminders)
        try data.write(to: url)
    }

    func loadLocalReminders() -> [VoiceReminder] {
        let url = getRemindersFileURL()
        guard let data = try? Data(contentsOf: url),
              let reminders = try? JSONDecoder().decode([VoiceReminder].self, from: data) else {
            return []
        }
        return reminders
    }

    func getTodaysReminders() -> [VoiceReminder] {
        let reminders = loadLocalReminders()
        let today = Calendar.current.startOfDay(for: Date())
        return reminders.filter {
            Calendar.current.isDate($0.createdAt, inSameDayAs: today)
        }
    }

    private func getRemindersFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("VoiceReminders.json")
    }

    // MARK: - Context

    func setContext(client: Client?, session: Appointment?) {
        currentClient = client
        currentSession = session
    }

    func clearContext() {
        currentClient = nil
        currentSession = nil
    }

    // MARK: - Helpers

    var hasTranscription: Bool {
        !partialTranscription.isEmpty || currentReminder != nil
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func reset() {
        cancelDictation()
        currentReminder = nil
        error = nil
    }
}
