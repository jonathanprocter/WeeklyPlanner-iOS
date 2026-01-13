import Foundation
import Combine

@MainActor
class SessionNoteViewModel: ObservableObject {
    @Published var currentNote: SessionNote?
    @Published var clientNotes: [SessionNote] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadNotes(for clientId: String, limit: Int = 10) async {
        isLoading = true
        error = nil

        do {
            clientNotes = try await apiClient.getSessionNotes(clientId: clientId, limit: limit)
            currentNote = clientNotes.first
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadNote(id: String) async {
        isLoading = true
        error = nil

        do {
            currentNote = try await apiClient.getProgressNote(id: id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func saveNote(_ input: SessionNoteInput) async -> Bool {
        isSaving = true
        error = nil

        do {
            let note = try await apiClient.createProgressNote(input)
            currentNote = note
            // Add to local list
            clientNotes.insert(note, at: 0)
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func clearCurrentNote() {
        currentNote = nil
    }

    // Helper to get most recent note for a client
    var mostRecentNote: SessionNote? {
        clientNotes.first
    }

    // Get key themes across recent sessions
    var aggregatedThemes: [String] {
        var themes: [String: Int] = [:]
        for note in clientNotes {
            for theme in note.tags ?? [] {
                themes[theme, default: 0] += 1
            }
        }
        return themes.sorted { $0.value > $1.value }.map { $0.key }
    }

    // Get AI-detected tags across sessions
    var aggregatedAITags: [String] {
        var tags: [String: Int] = [:]
        for note in clientNotes {
            for tag in note.aiTags ?? [] {
                tags[tag, default: 0] += 1
            }
        }
        return tags.sorted { $0.value > $1.value }.map { $0.key }
    }
}
