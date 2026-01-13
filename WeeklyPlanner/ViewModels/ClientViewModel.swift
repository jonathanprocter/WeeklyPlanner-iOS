import Foundation
import Combine

@MainActor
class ClientViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var selectedClient: Client?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchQuery = ""

    private let apiClient = APIClient.shared

    var filteredClients: [Client] {
        if searchQuery.isEmpty {
            return clients
        }
        return clients.filter { client in
            client.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var activeClients: [Client] {
        clients.filter { $0.status == .active || $0.status == nil }
    }

    func loadClients() async {
        isLoading = true
        error = nil

        do {
            clients = try await apiClient.getClients()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadClient(id: String) async {
        isLoading = true
        error = nil

        do {
            selectedClient = try await apiClient.getClient(id: id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createClient(_ input: ClientInput) async -> Client? {
        isLoading = true
        error = nil

        do {
            let client = try await apiClient.createClient(input)
            await loadClients()
            return client
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func updateClient(id: String, input: ClientInput) async -> Bool {
        isLoading = true
        error = nil

        do {
            _ = try await apiClient.updateClient(id: id, input: input)
            await loadClients()
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func deleteClient(id: String) async -> Bool {
        isLoading = true
        error = nil

        do {
            try await apiClient.deleteClient(id: id)
            clients.removeAll { $0.id == id }
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func clientForAppointment(_ appointment: Appointment) -> Client? {
        guard let clientId = appointment.clientId else { return nil }
        return clients.first { $0.id == clientId }
    }

    func clientByName(_ name: String) -> Client? {
        clients.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }
}
