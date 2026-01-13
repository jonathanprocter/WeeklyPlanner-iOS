import SwiftUI

struct ClientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clientViewModel: ClientViewModel

    @Binding var selectedClient: Client?
    @State private var searchText = ""

    var filteredClients: [Client] {
        let activeClients = clientViewModel.clients.filter {
            $0.status == .active || $0.status == nil
        }

        if searchText.isEmpty {
            return activeClients
        }
        return activeClients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredClients.isEmpty {
                    if clientViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Clients")
                                .font(.headline)
                            Text("Add clients in TherapyFlow to see them here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Results")
                                .font(.headline)
                            Text("No clients match \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(filteredClients) { client in
                        ClientRow(client: client, isSelected: selectedClient?.id == client.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedClient = client
                                dismiss()
                            }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search clients")
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if selectedClient != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            selectedClient = nil
                            dismiss()
                        }
                    }
                }
            }
            .task {
                if clientViewModel.clients.isEmpty {
                    await clientViewModel.loadClients()
                }
            }
        }
    }
}

struct ClientRow: View {
    let client: Client
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initials)
                        .font(.headline)
                        .foregroundColor(.white)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)

                if let tags = client.tags, !tags.isEmpty {
                    Text(tags.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let parts = client.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(client.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        // Generate consistent color from name
        let hash = abs(client.name.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Compact Client Picker (Inline)

struct CompactClientPicker: View {
    @EnvironmentObject var clientViewModel: ClientViewModel
    @Binding var selectedClient: Client?
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                if let client = selectedClient {
                    Circle()
                        .fill(avatarColor(for: client))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text(initials(for: client))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    Text(client.name)
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                    Text("Select Client")
                        .foregroundColor(.blue)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            ClientPickerView(selectedClient: $selectedClient)
        }
    }

    private func initials(for client: Client) -> String {
        let parts = client.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(client.name.prefix(2)).uppercased()
    }

    private func avatarColor(for client: Client) -> Color {
        let hash = abs(client.name.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        return colors[hash % colors.count]
    }
}

#Preview {
    ClientPickerView(selectedClient: .constant(nil))
        .environmentObject(ClientViewModel())
}
