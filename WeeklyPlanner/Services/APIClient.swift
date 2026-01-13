import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case notFound
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown error")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notFound:
            return "Resource not found"
        case .accessDenied:
            return "Access denied"
        }
    }
}

class APIClient {
    static let shared = APIClient()

    // TherapyFlow backend URL - change this to your Render URL in production
    private var baseURL: String {
        // Check for custom URL in UserDefaults (for development)
        if let customURL = UserDefaults.standard.string(forKey: "api_base_url"), !customURL.isEmpty {
            return customURL
        }
        // Default to TherapyFlow backend on Render
        return "https://therapyflow-backend.onrender.com/api"
    }

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try simple date format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            // Try with timezone
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic Request Helper

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = queryItems?.isEmpty == false ? queryItems : nil

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw APIError.decodingError(error)
            }
        case 403:
            throw APIError.accessDenied
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    // Void response variant
    private func requestVoid(
        _ method: String,
        path: String,
        body: Encodable? = nil
    ) async throws {
        var components = URLComponents(string: "\(baseURL)\(path)")

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Clients

    func getClients() async throws -> [Client] {
        try await request("GET", path: "/clients")
    }

    func getClient(id: String) async throws -> Client? {
        try await request("GET", path: "/clients/\(id)")
    }

    func createClient(_ input: ClientInput) async throws -> Client {
        try await request("POST", path: "/clients", body: input)
    }

    func updateClient(id: String, input: ClientInput) async throws -> Client {
        try await request("PUT", path: "/clients/\(id)", body: input)
    }

    func deleteClient(id: String) async throws {
        try await requestVoid("DELETE", path: "/clients/\(id)")
    }

    // MARK: - Sessions/Appointments

    func getSessions(
        clientId: String? = nil,
        upcoming: Bool? = nil,
        today: Bool? = nil,
        includePast: Bool? = nil,
        limit: Int? = nil
    ) async throws -> [Appointment] {
        var queryItems: [URLQueryItem] = []

        if let clientId = clientId {
            queryItems.append(URLQueryItem(name: "clientId", value: clientId))
        }
        if upcoming == true {
            queryItems.append(URLQueryItem(name: "upcoming", value: "true"))
        }
        if today == true {
            queryItems.append(URLQueryItem(name: "today", value: "true"))
        }
        if includePast == true {
            queryItems.append(URLQueryItem(name: "includePast", value: "true"))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return try await request("GET", path: "/sessions", queryItems: queryItems)
    }

    func getSession(id: String) async throws -> Appointment? {
        try await request("GET", path: "/sessions/\(id)")
    }

    func createSession(_ input: AppointmentInput) async throws -> Appointment {
        try await request("POST", path: "/sessions", body: input)
    }

    func updateSession(id: String, input: AppointmentInput) async throws -> Appointment {
        try await request("PUT", path: "/sessions/\(id)", body: input)
    }

    // Legacy method names for compatibility
    func getAppointmentsByDateRange(startDate: String, endDate: String) async throws -> [Appointment] {
        // TherapyFlow doesn't have date range - get all and filter
        let sessions = try await getSessions(includePast: true, limit: 500)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let start = formatter.date(from: startDate),
              let end = formatter.date(from: endDate) else {
            return sessions
        }

        return sessions.filter { session in
            session.scheduledAt >= start && session.scheduledAt <= end.addingTimeInterval(86400)
        }
    }

    func getAllAppointments() async throws -> [Appointment] {
        try await getSessions(includePast: true, limit: 500)
    }

    func createAppointment(_ input: AppointmentInput) async throws -> String {
        let session = try await createSession(input)
        return session.id
    }

    func updateAppointment(id: String, input: AppointmentInput) async throws {
        _ = try await updateSession(id: id, input: input)
    }

    func deleteAppointment(id: String) async throws {
        // TherapyFlow doesn't have session delete - update status to cancelled
        struct CancelInput: Codable {
            let status: String
        }
        try await requestVoid("PUT", path: "/sessions/\(id)", body: CancelInput(status: "cancelled"))
    }

    // MARK: - Progress Notes (Session Notes)

    func getProgressNotes(clientId: String, limit: Int = 10) async throws -> [SessionNote] {
        let queryItems = [
            URLQueryItem(name: "clientId", value: clientId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request("GET", path: "/progress-notes", queryItems: queryItems)
    }

    func getProgressNote(id: String) async throws -> SessionNote? {
        try await request("GET", path: "/progress-notes/\(id)")
    }

    func createProgressNote(_ input: SessionNoteInput) async throws -> SessionNote {
        try await request("POST", path: "/progress-notes", body: input)
    }

    // Legacy method names
    func getSessionNote(appointmentId: String) async throws -> SessionNote? {
        // Get notes for the session's client, then filter
        // TherapyFlow doesn't have direct session->note lookup without clientId
        return nil
    }

    func getSessionNotes(clientId: String, limit: Int = 10) async throws -> [SessionNote] {
        try await getProgressNotes(clientId: clientId, limit: limit)
    }

    func createSessionNote(_ input: SessionNoteInput) async throws -> String {
        let note = try await createProgressNote(input)
        return note.id
    }

    func updateSessionNote(id: String, input: SessionNoteInput) async throws {
        // TherapyFlow doesn't have note update endpoint - would need to add
    }

    // MARK: - Session Prep

    func getSessionPrep(sessionId: String, clientId: String = "") async throws -> SessionPrep? {
        do {
            let response: SessionPrepResponse = try await request("GET", path: "/sessions/\(sessionId)/prep-ai/latest")
            return SessionPrep(from: response, sessionId: sessionId, clientId: clientId)
        } catch APIError.notFound {
            return nil
        } catch APIError.decodingError {
            // API returns {"error": "..."} when not found, which fails to decode
            return nil
        }
    }

    func generateSessionPrep(sessionId: String) async throws -> SessionPrepResponse {
        try await request("POST", path: "/sessions/\(sessionId)/prep-ai")
    }

    // Legacy method
    func generateSessionPrep(appointmentId: String, clientId: String, lookbackSessions: Int = 3) async throws -> SessionPrep {
        let response = try await generateSessionPrep(sessionId: appointmentId)
        return SessionPrep(from: response, sessionId: appointmentId, clientId: clientId)
    }

    // MARK: - Google Calendar Sync (if still needed)

    func syncFromGoogle(events: [[String: Any]]) async throws -> SyncResult {
        // This would need a different approach with TherapyFlow
        // For now, return empty result
        return SyncResult(synced: 0, deleted: 0)
    }

    // MARK: - Daily Notes (legacy - may not be in TherapyFlow)

    func getDailyNote(date: String) async throws -> DailyNote? {
        // TherapyFlow doesn't have daily notes
        return nil
    }

    func saveDailyNote(_ input: DailyNoteInput) async throws -> Int {
        // TherapyFlow doesn't have daily notes
        return 0
    }
}

// MARK: - Response Types

struct SuccessResponse: Codable {
    let success: Bool
    let message: String?
}
