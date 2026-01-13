import Foundation
import Combine

@MainActor
class SessionPrepViewModel: ObservableObject {
    @Published var prep: SessionPrep?
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadPrep(for sessionId: String) async {
        isLoading = true
        error = nil

        do {
            prep = try await apiClient.getSessionPrep(sessionId: sessionId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func generatePrep(sessionId: String, clientId: String) async {
        isGenerating = true
        error = nil

        do {
            prep = try await apiClient.generateSessionPrep(
                appointmentId: sessionId,
                clientId: clientId,
                lookbackSessions: 3
            )
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    func refreshPrep(sessionId: String, clientId: String) async {
        // Clear existing prep and regenerate
        prep = nil
        await generatePrep(sessionId: sessionId, clientId: clientId)
    }

    func clearPrep() {
        prep = nil
        error = nil
    }

    var hasPrep: Bool {
        prep != nil
    }
}
