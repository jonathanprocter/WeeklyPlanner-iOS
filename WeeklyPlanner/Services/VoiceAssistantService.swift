import Foundation
import Combine

@MainActor
class VoiceAssistantService: ObservableObject {
    // MARK: - Published State

    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var isProcessing = false
    @Published var conversation: VoiceConversation
    @Published var error: String?

    // Services
    private let speechService = SpeechRecognitionService()
    private let elevenLabsService = ElevenLabsService()
    private let aiService = AIProcessingService()
    private var apiClient: APIClient?

    // Conversation context
    private var conversationContext = ConversationContext()

    private let bargeInKey = "voiceAssistantBargeInEnabled"
    private let conversationModeKey = "voiceAssistantConversationModeEnabled"

    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient
        self.conversation = VoiceConversation()
        setupBindings()
    }

    private func setupBindings() {
        speechService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isListening)

        elevenLabsService.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
    }

    // MARK: - Authorization

    var isAuthorized: Bool {
        speechService.isAuthorized
    }

    func requestAuthorization() async -> Bool {
        return await speechService.requestAuthorization()
    }

    // MARK: - Conversation Flow

    func startListening() async {
        error = nil

        if UserDefaults.standard.bool(forKey: bargeInKey) {
            stopSpeaking()
        }

        do {
            try await speechService.startRecording()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stopListeningAndProcess() async {
        speechService.stopRecording()
        let userText = speechService.getTranscription()

        guard !userText.isEmpty else {
            return
        }

        // Add user message to conversation
        let userMessage = ConversationMessage(role: .user, content: userText)
        conversation.messages.append(userMessage)

        await processQuery(userText)
    }

    func processTextQuery(_ text: String) async {
        let userMessage = ConversationMessage(role: .user, content: text)
        conversation.messages.append(userMessage)

        await processQuery(text)
    }

    private func processQuery(_ text: String) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Parse intent
            var intent = try await aiService.parseIntent(from: text, context: conversationContext)
            if intent.timeReference == nil {
                intent.timeReference = inferTimeReference(from: text)
            }

            // Execute the intent and get data
            let data = await executeIntent(intent)

            // Generate response
            let responseText = try await aiService.generateResponse(
                for: intent,
                data: data,
                context: conversationContext
            )

            // Add assistant message
            let assistantMessage = ConversationMessage(
                role: .assistant,
                content: responseText,
                intent: intent
            )
            conversation.messages.append(assistantMessage)

            // Update context
            updateContext(with: intent)

            // Speak the response
            await speakResponse(responseText)

            if UserDefaults.standard.bool(forKey: conversationModeKey), isAuthorized {
                await startListening()
            }

        } catch {
            let errorMessage = "I'm sorry, I encountered an error: \(error.localizedDescription)"
            let errorResponse = ConversationMessage(role: .assistant, content: errorMessage)
            conversation.messages.append(errorResponse)
            await speakResponse(errorMessage)
        }
    }

    // MARK: - Intent Execution

    private func executeIntent(_ intent: DetectedIntent) async -> Any? {
        guard let apiClient = apiClient else {
            return nil
        }

        switch intent.action {
        case .queryNextAppointment:
            return await fetchNextAppointment(apiClient)

        case .queryClientHistory:
            if let clientName = intent.entityName {
                return await fetchClientHistory(for: clientName, apiClient: apiClient)
            }
            return nil

        case .queryPreviousSession:
            if let clientName = intent.entityName {
                return await fetchPreviousSession(for: clientName, apiClient: apiClient)
            }
            return nil

        case .querySessionPrep:
            if let clientName = intent.entityName {
                return await fetchSessionPrep(for: clientName, apiClient: apiClient)
            }
            return nil

        case .createReminder:
            // Return the text to create a reminder from
            return intent.entityName ?? "Reminder created"

        case .searchClients:
            if let query = intent.entityName {
                return await searchClients(query: query, apiClient: apiClient)
            }
            return nil

        case .getSchedule:
            return await fetchSchedule(apiClient, timeReference: intent.timeReference)

        case .getDailySummary:
            return await fetchSchedule(apiClient, timeReference: intent.timeReference)

        case .getClientInfo:
            if let clientName = intent.entityName {
                return await fetchClientByName(clientName, apiClient: apiClient)
            }
            return nil

        case .unknown:
            return nil
        }
    }

    // MARK: - API Calls

    private func fetchNextAppointment(_ apiClient: APIClient) async -> Appointment? {
        do {
            let appointments = try await apiClient.getAllAppointments()
            let now = Date()
            return appointments
                .filter { $0.scheduledAt > now }
                .sorted { $0.scheduledAt < $1.scheduledAt }
                .first
        } catch {
            return nil
        }
    }

    private func fetchTodaySchedule(_ apiClient: APIClient) async -> [Appointment]? {
        await fetchSchedule(apiClient, timeReference: TimeReference(type: .today))
    }

    private func fetchClientByName(_ name: String, apiClient: APIClient) async -> Client? {
        do {
            let clients = try await apiClient.getClients()
            return clients.first {
                $0.name.localizedCaseInsensitiveContains(name)
            }
        } catch {
            return nil
        }
    }

    private func searchClients(query: String, apiClient: APIClient) async -> [Client]? {
        do {
            let clients = try await apiClient.getClients()
            return clients.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        } catch {
            return nil
        }
    }

    private func fetchPreviousSession(for clientName: String, apiClient: APIClient) async -> SessionNote? {
        do {
            let clients = try await apiClient.getClients()
            guard let client = clients.first(where: {
                $0.name.localizedCaseInsensitiveContains(clientName)
            }) else {
                return nil
            }

            let notes = try await apiClient.getSessionNotes(clientId: client.id)
            let sortedNotes = notes.sorted { (a: SessionNote, b: SessionNote) in a.sessionDate > b.sessionDate }
            return sortedNotes.first
        } catch {
            return nil
        }
    }

    private func fetchClientHistory(for clientName: String, apiClient: APIClient) async -> [SessionNote]? {
        do {
            let clients = try await apiClient.getClients()
            guard let client = clients.first(where: {
                $0.name.localizedCaseInsensitiveContains(clientName)
            }) else {
                return nil
            }
            return try await apiClient.getSessionNotes(clientId: client.id, limit: 10)
        } catch {
            return nil
        }
    }

    private func fetchSessionPrep(for clientName: String, apiClient: APIClient) async -> SessionPrep? {
        do {
            let clients = try await apiClient.getClients()
            guard let client = clients.first(where: { c in
                c.name.localizedCaseInsensitiveContains(clientName)
            }) else {
                return nil
            }

            // Get the client's next appointment
            let appointments = try await apiClient.getAllAppointments()
            let now = Date()
            let clientAppointments = appointments.filter { appointment in
                appointment.clientId == client.id && appointment.scheduledAt > now
            }
            let sortedAppointments = clientAppointments.sorted { (a: Appointment, b: Appointment) in
                a.scheduledAt < b.scheduledAt
            }
            guard let nextAppointment = sortedAppointments.first else {
                return nil
            }

            return try await apiClient.getSessionPrep(sessionId: nextAppointment.id, clientId: client.id)
        } catch {
            return nil
        }
    }

    private func fetchDailySummary(_ apiClient: APIClient) async -> [Appointment]? {
        await fetchSchedule(apiClient, timeReference: TimeReference(type: .today))
    }

    // MARK: - Text to Speech

    private func speakResponse(_ text: String) async {
        if elevenLabsService.isConfigured {
            do {
                try await elevenLabsService.speakText(text)
            } catch {
                // Fallback to system voice
                await elevenLabsService.speakWithSystemVoiceAsync(text)
            }
        } else {
            await elevenLabsService.speakWithSystemVoiceAsync(text)
        }
    }

    func stopSpeaking() {
        elevenLabsService.stopSpeaking()
    }

    // MARK: - Context Management

    private func updateContext(with intent: DetectedIntent) {
        conversationContext.lastIntent = intent.action

        if let clientName = intent.entityName {
            conversationContext.currentClientName = clientName
        }
    }

    private func inferTimeReference(from text: String) -> TimeReference? {
        let lowered = text.lowercased()
        if lowered.contains("tomorrow") {
            return TimeReference(type: .tomorrow)
        }
        if lowered.contains("today") {
            return TimeReference(type: .today)
        }
        if lowered.contains("next week") {
            return TimeReference(type: .nextWeek)
        }
        if lowered.contains("this week") {
            return TimeReference(type: .thisWeek)
        }
        return nil
    }

    private func fetchSchedule(_ apiClient: APIClient, timeReference: TimeReference?) async -> [Appointment]? {
        do {
            let appointments = try await apiClient.getAllAppointments()
            let (startDate, endDate) = scheduleDateRange(for: timeReference)

            let filtered = appointments.filter { appointment in
                appointment.scheduledAt >= startDate && appointment.scheduledAt < endDate
            }
            return filtered.sorted { (a: Appointment, b: Appointment) in
                a.scheduledAt < b.scheduledAt
            }
        } catch {
            return nil
        }
    }

    private func scheduleDateRange(for timeReference: TimeReference?) -> (Date, Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let timeReference else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return (today, tomorrow)
        }

        switch timeReference.type {
        case .today:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return (today, tomorrow)
        case .tomorrow:
            let start = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 2, to: today) ?? start
            return (start, end)
        case .thisWeek:
            let start = Date().startOfWeek
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .nextWeek:
            let start = calendar.date(byAdding: .day, value: 7, to: Date().startOfWeek) ?? today
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .specific:
            if let date = timeReference.date {
                let start = calendar.startOfDay(for: date)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                return (start, end)
            }
        case .range:
            if let start = timeReference.startDate, let end = timeReference.endDate {
                return (start, end)
            }
        case .relative, .lastSession:
            break
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return (today, tomorrow)
    }

    func clearConversation() {
        conversation = VoiceConversation()
        conversationContext = ConversationContext()
    }

    // MARK: - Quick Commands

    func askAboutNextAppointment() async {
        await processTextQuery("When is my next appointment?")
    }

    func askAboutTodaySchedule() async {
        await processTextQuery("What's on my schedule today?")
    }

    func askAboutClient(_ clientName: String) async {
        await processTextQuery("Tell me about \(clientName)")
    }
}

// ConversationContext is defined in VoiceConversation.swift
