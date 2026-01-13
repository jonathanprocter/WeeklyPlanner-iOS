import Foundation
@preconcurrency import AuthenticationServices

// Google Calendar Service using ASWebAuthenticationSession for OAuth
class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()

    // Google OAuth credentials
    private let clientId = "203333002256-atur62lftntm8kea6u7b2kj44c8hmsru.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.203333002256-atur62lftntm8kea6u7b2kj44c8hmsru:/oauth2callback"

    @Published var isSignedIn = false
    @Published var calendars: [GoogleCalendar] = []

    private var accessToken: String?
    private var refreshToken: String?

    private override init() {
        super.init()
        loadTokens()
    }

    // MARK: - Token Management

    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: "google_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "google_refresh_token")
        isSignedIn = accessToken != nil
    }

    private func saveTokens(access: String, refresh: String?) {
        accessToken = access
        refreshToken = refresh
        UserDefaults.standard.set(access, forKey: "google_access_token")
        if let refresh = refresh {
            UserDefaults.standard.set(refresh, forKey: "google_refresh_token")
        }
        isSignedIn = true
    }

    private func clearTokens() {
        accessToken = nil
        refreshToken = nil
        UserDefaults.standard.removeObject(forKey: "google_access_token")
        UserDefaults.standard.removeObject(forKey: "google_refresh_token")
        isSignedIn = false
        calendars = []
    }

    // MARK: - OAuth Flow

    func signIn() async throws {
        let scope = "https://www.googleapis.com/auth/calendar.readonly"
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth?" +
            "client_id=\(clientId)" +
            "&redirect_uri=\(redirectURI)" +
            "&response_type=code" +
            "&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)" +
            "&access_type=offline" +
            "&prompt=consent"

        guard let url = URL(string: authURL) else {
            throw GoogleCalendarError.invalidURL
        }

        // Use ASWebAuthenticationSession for OAuth
        let authCode = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.googleusercontent.apps.203333002256-atur62lftntm8kea6u7b2kj44c8hmsru") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GoogleCalendarError.noAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                session.start()
            }
        }

        // Exchange auth code for tokens
        try await exchangeCodeForTokens(authCode)
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "code=\(code)&client_id=\(clientId)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GoogleCalendarError.tokenExchangeFailed
        }

        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        await MainActor.run {
            saveTokens(access: tokenResponse.access_token, refresh: tokenResponse.refresh_token)
        }
    }

    func signOut() {
        clearTokens()
    }

    // MARK: - Calendar API

    func fetchCalendarList() async throws -> [GoogleCalendar] {
        guard let token = accessToken else {
            throw GoogleCalendarError.notSignedIn
        }

        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Token expired, try to refresh
            try await refreshAccessToken()
            return try await fetchCalendarList()
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        struct CalendarListResponse: Codable {
            let items: [CalendarItem]

            struct CalendarItem: Codable {
                let id: String
                let summary: String
            }
        }

        let listResponse = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        let calendars = listResponse.items.map { GoogleCalendar(id: $0.id, summary: $0.summary) }

        await MainActor.run {
            self.calendars = calendars
        }

        return calendars
    }

    func fetchEvents(calendarId: String, from startDate: Date, to endDate: Date) async throws -> [GoogleCalendarEvent] {
        guard let token = accessToken else {
            throw GoogleCalendarError.notSignedIn
        }

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? calendarId
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarId)/events?" +
            "timeMin=\(timeMin)&timeMax=\(timeMax)&maxResults=2500&singleEvents=true&orderBy=startTime"

        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            try await refreshAccessToken()
            return try await fetchEvents(calendarId: calendarId, from: startDate, to: endDate)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        struct EventsResponse: Codable {
            let items: [GoogleCalendarEvent]?
        }

        let eventsResponse = try JSONDecoder().decode(EventsResponse.self, from: data)
        return eventsResponse.items ?? []
    }

    private func refreshAccessToken() async throws {
        guard let refresh = refreshToken else {
            throw GoogleCalendarError.noRefreshToken
        }

        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "refresh_token=\(refresh)&client_id=\(clientId)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            clearTokens()
            throw GoogleCalendarError.tokenRefreshFailed
        }

        struct RefreshResponse: Codable {
            let access_token: String
        }

        let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)

        await MainActor.run {
            accessToken = refreshResponse.access_token
            UserDefaults.standard.set(refreshResponse.access_token, forKey: "google_access_token")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Errors

enum GoogleCalendarError: Error, LocalizedError {
    case invalidURL
    case noAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notSignedIn
    case noRefreshToken
    case invalidResponse
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noAuthCode:
            return "No authorization code received"
        case .tokenExchangeFailed:
            return "Failed to exchange auth code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .notSignedIn:
            return "Not signed in to Google"
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidResponse:
            return "Invalid response from Google"
        case .apiError(let code):
            return "Google API error: \(code)"
        }
    }
}
