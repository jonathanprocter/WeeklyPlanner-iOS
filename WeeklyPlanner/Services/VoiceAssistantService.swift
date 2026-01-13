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
            let intent = try await aiService.parseIntent(from: text, context: conversationContext)

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
                return await fetchClientByName(clientName, apiClient: apiClient)
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
            return await fetchTodaySchedule(apiClient)

        case .getDailySummary:
            return await fetchDailySummary(apiClient)

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
        do {
            let appointments = try await apiClient.getAllAppointments()
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            let todayAppointments = appointments.filter { appointment in
                appointment.scheduledAt >= today && appointment.scheduledAt < tomorrow
            }
            return todayAppointments.sorted { (a: Appointment, b: Appointment) in
                a.scheduledAt < b.scheduledAt
            }
        } catch {
            return nil
        }
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
        return await fetchTodaySchedule(apiClient)
    }

    // MARK: - Text to Speech

    private func speakResponse(_ text: String) async {
        if elevenLabsService.isConfigured {
            do {
                try await elevenLabsService.speakText(text)
            } catch {
                // Fallback to system voice
                elevenLabsService.speakWithSystemVoice(text)
            }
        } else {
            elevenLabsService.speakWithSystemVoice(text)
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
