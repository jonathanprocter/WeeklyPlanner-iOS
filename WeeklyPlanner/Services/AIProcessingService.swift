import Foundation

enum AIProvider: String, Codable {
    case claude
    case openai
    case none
}

enum AIProcessingError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case rateLimited
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No AI API key configured"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .serviceUnavailable:
            return "AI service temporarily unavailable"
        }
    }
}

@MainActor
class AIProcessingService: ObservableObject {
    @Published var isProcessing = false
    @Published var currentProvider: AIProvider = .none
    @Published var error: AIProcessingError?

    private let keychain = KeychainService.shared

    // API endpoints
    private let claudeBaseURL = "https://api.anthropic.com/v1"
    private let openAIBaseURL = "https://api.openai.com/v1"

    // MARK: - Configuration

    var hasClaudeKey: Bool { keychain.hasClaudeKey }
    var hasOpenAIKey: Bool { keychain.hasOpenAIKey }
    var hasAnyKey: Bool { hasClaudeKey || hasOpenAIKey }

    func getPreferredProvider() -> AIProvider {
        if hasClaudeKey { return .claude }
        if hasOpenAIKey { return .openai }
        return .none
    }

    // MARK: - Reminder Processing

    func processReminder(_ transcription: String, clientContext: Client?) async throws -> ProcessedReminder {
        let prompt = buildReminderProcessingPrompt(transcription: transcription, clientContext: clientContext)
        let response = try await sendPrompt(prompt, systemPrompt: reminderSystemPrompt)
        return try parseReminderResponse(response)
    }

    func extractFollowUps(from transcription: String) async throws -> [String] {
        let prompt = """
        Extract specific follow-up items from this therapy session note.
        Return only a JSON array of strings, each being a clear action item.

        Note: "\(transcription)"
        """

        let response = try await sendPrompt(prompt, systemPrompt: "You are a clinical assistant. Extract follow-up items and return them as a JSON array of strings.")
        return try parseStringArray(response)
    }

    func categorizeReminder(_ transcription: String) async throws -> ReminderCategory {
        let prompt = """
        Categorize this therapy reminder into one of these categories:
        - session_follow_up: Related to client session follow-up
        - clinical_note: Clinical observation to document
        - homework: Homework assignment reminder
        - risk_flag: Risk-related notation requiring attention
        - administrative: Billing, scheduling, admin tasks
        - personal: Personal reminder
        - urgent: Requires immediate attention

        Note: "\(transcription)"

        Return only the category key as a single word.
        """

        let response = try await sendPrompt(prompt, systemPrompt: "You are a clinical assistant. Categorize the reminder and return only the category key.")
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ReminderCategory(rawValue: cleaned) ?? .sessionFollowUp
    }

    func assessPriority(_ transcription: String, clientRiskLevel: RiskLevel?) async throws -> ReminderPriority {
        let riskContext = clientRiskLevel.map { "Client's current risk level: \($0.rawValue)" } ?? ""

        let prompt = """
        Assess the priority of this therapy reminder:
        - low: Can be addressed in future sessions
        - medium: Should be addressed soon
        - high: Important, address in next session
        - critical: Urgent, requires immediate attention

        \(riskContext)

        Note: "\(transcription)"

        Return only the priority level as a single word.
        """

        let response = try await sendPrompt(prompt, systemPrompt: "You are a clinical assistant. Assess priority and return only the priority level.")
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ReminderPriority(rawValue: cleaned) ?? .medium
    }

    // MARK: - Voice Assistant Intent Parsing

    func parseIntent(from text: String, context: ConversationContext?) async throws -> DetectedIntent {
        let contextInfo = buildContextInfo(context)

        let prompt = """
        Parse the user's intent from this query and return a JSON object with these fields:
        - action: One of: query_next_appointment, query_client_history, query_previous_session, query_session_prep, create_reminder, search_clients, get_schedule, get_daily_summary, get_client_info, unknown
        - entity_type: Optional - "client", "appointment", "session", etc.
        - entity_name: Optional - Name mentioned (e.g., client name)
        - time_reference: Optional object with "type" (today, tomorrow, this_week, next_week, last_session, specific)

        \(contextInfo)

        User query: "\(text)"

        Return only valid JSON.
        """

        let response = try await sendPrompt(prompt, systemPrompt: intentParsingSystemPrompt)
        return try parseIntentResponse(response)
    }

    func generateResponse(for intent: DetectedIntent, data: Any?, context: ConversationContext?) async throws -> String {
        let dataDescription = describeData(data)
        let contextInfo = buildContextInfo(context)

        let prompt = """
        Generate a natural, conversational response for a therapy practice assistant.

        Intent: \(intent.action.rawValue)
        \(intent.entityName.map { "Entity: \($0)" } ?? "")
        \(contextInfo)

        Data retrieved:
        \(dataDescription)

        Generate a helpful, concise response. Be professional but warm.
        """

        return try await sendPrompt(prompt, systemPrompt: assistantResponseSystemPrompt)
    }

    // MARK: - Daily Summary

    func generateDailySummary(reminders: [VoiceReminder], sessions: [Appointment]) async throws -> String {
        let remindersText = reminders.map { "- \($0.transcription) [\($0.priority.rawValue)]" }.joined(separator: "\n")
        let sessionsText = sessions.map { "- \($0.title) at \($0.startTime.formatted(date: .omitted, time: .shortened))" }.joined(separator: "\n")

        let prompt = """
        Generate a brief end-of-day summary for a therapist.

        Voice reminders recorded today:
        \(remindersText.isEmpty ? "None" : remindersText)

        Sessions completed today:
        \(sessionsText.isEmpty ? "None" : sessionsText)

        Provide a concise, actionable summary highlighting:
        1. Key items requiring attention
        2. Any risk-related notes
        3. Important follow-ups for tomorrow

        Keep it brief and scannable.
        """

        return try await sendPrompt(prompt, systemPrompt: summarySystemPrompt)
    }

    // MARK: - Core API Communication

    private func sendPrompt(_ prompt: String, systemPrompt: String) async throws -> String {
        // Try Claude first, fall back to OpenAI
        if hasClaudeKey {
            do {
                currentProvider = .claude
                return try await sendClaudeRequest(prompt: prompt, systemPrompt: systemPrompt)
            } catch {
                if hasOpenAIKey {
                    currentProvider = .openai
                    return try await sendOpenAIRequest(prompt: prompt, systemPrompt: systemPrompt)
                }
                throw error
            }
        } else if hasOpenAIKey {
            currentProvider = .openai
            return try await sendOpenAIRequest(prompt: prompt, systemPrompt: systemPrompt)
        } else {
            throw AIProcessingError.noAPIKey
        }
    }

    private func sendClaudeRequest(prompt: String, systemPrompt: String) async throws -> String {
        guard let apiKey = keychain.claudeAPIKey else {
            throw AIProcessingError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "\(claudeBaseURL)/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        isProcessing = true
        defer { isProcessing = false }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                throw AIProcessingError.invalidResponse
            }
            return text
        case 429:
            throw AIProcessingError.rateLimited
        case 503:
            throw AIProcessingError.serviceUnavailable
        default:
            throw AIProcessingError.invalidResponse
        }
    }

    private func sendOpenAIRequest(prompt: String, systemPrompt: String) async throws -> String {
        guard let apiKey = keychain.openAIAPIKey else {
            throw AIProcessingError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "\(openAIBaseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        isProcessing = true
        defer { isProcessing = false }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIProcessingError.invalidResponse
            }
            return content
        case 429:
            throw AIProcessingError.rateLimited
        case 503:
            throw AIProcessingError.serviceUnavailable
        default:
            throw AIProcessingError.invalidResponse
        }
    }

    // MARK: - Response Parsing

    private func parseReminderResponse(_ response: String) throws -> ProcessedReminder {
        // Try to extract JSON from response
        let cleanedResponse = extractJSON(from: response)

        guard let data = cleanedResponse.data(using: .utf8) else {
            throw AIProcessingError.decodingError(NSError(domain: "AIProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
        }

        do {
            return try JSONDecoder().decode(ProcessedReminder.self, from: data)
        } catch {
            // If decoding fails, create a basic ProcessedReminder
            return ProcessedReminder(
                extractedFollowUps: [],
                suggestedCategory: .sessionFollowUp,
                suggestedPriority: .medium,
                keyEntities: [],
                actionItems: []
            )
        }
    }

    private func parseIntentResponse(_ response: String) throws -> DetectedIntent {
        let cleanedResponse = extractJSON(from: response)

        guard let data = cleanedResponse.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return DetectedIntent(action: .unknown)
        }

        let actionString = json["action"] as? String ?? "unknown"
        let action = IntentAction(rawValue: actionString) ?? .unknown

        var timeRef: TimeReference?
        if let timeJson = json["time_reference"] as? [String: Any],
           let typeString = timeJson["type"] as? String,
           let type = TimeReferenceType(rawValue: typeString) {
            timeRef = TimeReference(type: type)
        }

        return DetectedIntent(
            action: action,
            entityType: json["entity_type"] as? String,
            entityId: json["entity_id"] as? String,
            entityName: json["entity_name"] as? String,
            timeReference: timeRef
        )
    }

    private func parseStringArray(_ response: String) throws -> [String] {
        let cleanedResponse = extractJSON(from: response)
        guard let data = cleanedResponse.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON in the response
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        if let startIndex = text.firstIndex(of: "["),
           let endIndex = text.lastIndex(of: "]") {
            return String(text[startIndex...endIndex])
        }
        return text
    }

    // MARK: - Helpers

    private func buildReminderProcessingPrompt(transcription: String, clientContext: Client?) -> String {
        var prompt = """
        Analyze this voice reminder from a therapy session and return a JSON object with:
        - extracted_follow_ups: Array of specific action items
        - suggested_category: One of session_follow_up, clinical_note, homework, risk_flag, administrative, personal, urgent
        - suggested_priority: One of low, medium, high, critical
        - key_entities: Array of important names, topics mentioned
        - action_items: Array of specific tasks to complete

        """

        if let client = clientContext {
            prompt += "\nClient context: \(client.name)"
            if let considerations = client.clinicalConsiderations, !considerations.isEmpty {
                prompt += "\nClinical considerations: \(considerations.joined(separator: ", "))"
            }
        }

        prompt += "\n\nReminder transcription: \"\(transcription)\"\n\nReturn only valid JSON."

        return prompt
    }

    private func buildContextInfo(_ context: ConversationContext?) -> String {
        guard let ctx = context else { return "" }
        var info = "Current context:"
        if let name = ctx.currentClientName {
            info += "\n- Currently discussing client: \(name)"
        }
        if let lastIntent = ctx.lastIntent {
            info += "\n- Previous query was about: \(lastIntent.rawValue)"
        }
        return info
    }

    private func describeData(_ data: Any?) -> String {
        guard let data = data else { return "No data found" }

        if let appointment = data as? Appointment {
            return "Appointment: \(appointment.title) on \(appointment.scheduledAt.formatted()) for \(appointment.duration) minutes"
        }
        if let appointments = data as? [Appointment] {
            return appointments.map { "\($0.title) at \($0.startTime.formatted(date: .omitted, time: .shortened))" }.joined(separator: "\n")
        }
        if let client = data as? Client {
            return "Client: \(client.name), Status: \(client.status)"
        }
        if let clients = data as? [Client] {
            return clients.map { $0.name }.joined(separator: ", ")
        }
        if let notes = data as? [SessionNote] {
            return notes.prefix(3).compactMap { $0.content?.prefix(100) }.map { String($0) }.joined(separator: "\n---\n")
        }
        if let prep = data as? SessionPrep {
            return prep.prep.sessionFocus ?? "Session prep available"
        }

        return String(describing: data)
    }

    // MARK: - System Prompts

    private let reminderSystemPrompt = """
    You are a clinical assistant for a mental health therapist. Your role is to analyze voice reminders
    recorded during or after therapy sessions and extract actionable information. Be precise and clinical
    in your analysis. Pay special attention to any risk indicators or urgent matters.
    """

    private let intentParsingSystemPrompt = """
    You are an intent parser for a therapy practice management assistant. Parse user queries and identify:
    1. What action they want (schedule lookup, client info, session history, etc.)
    2. Any entities mentioned (client names, dates, etc.)
    3. Time references (today, tomorrow, last session, etc.)
    Return structured JSON only.
    """

    private let assistantResponseSystemPrompt = """
    You are a helpful voice assistant for a mental health therapist's practice. Provide clear, concise
    responses about appointments, clients, and session information. Be professional but warm.
    Keep responses brief as they will be spoken aloud.
    """

    private let summarySystemPrompt = """
    You are a clinical assistant generating end-of-day summaries for a mental health therapist.
    Be concise, highlight important items, and flag any risk-related notes.
    Format for easy scanning.
    """
}
