import SwiftUI

struct AppointmentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: AppointmentViewModel
    @EnvironmentObject var clientViewModel: ClientViewModel

    let date: Date
    let existingAppointment: Appointment?

    @State private var selectedClient: Client?
    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var sessionType: SessionType = .individual
    @State private var status: AppointmentStatus = .scheduled
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showingClientPicker = false

    private var isEditing: Bool { existingAppointment != nil }

    init(date: Date, existingAppointment: Appointment? = nil) {
        self.date = date
        self.existingAppointment = existingAppointment

        if let existing = existingAppointment {
            _selectedClient = State(initialValue: existing.client)
            _selectedDate = State(initialValue: existing.scheduledAt)
            _startTime = State(initialValue: existing.scheduledAt)
            _endTime = State(initialValue: existing.endTime)
            _sessionType = State(initialValue: existing.sessionType ?? .individual)
            _status = State(initialValue: existing.status ?? .scheduled)
            _notes = State(initialValue: existing.notes ?? "")
        } else {
            _selectedDate = State(initialValue: date)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            let startOfHour = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: date) ?? date
            _startTime = State(initialValue: startOfHour)
            _endTime = State(initialValue: startOfHour.addingTimeInterval(50 * 60)) // 50 minutes default
        }
    }

    private var duration: Int {
        let interval = endTime.timeIntervalSince(startTime)
        return max(Int(interval / 60), 15) // Minimum 15 minutes
    }

    var body: some View {
        NavigationStack {
            Form {
                // Client Selection
                Section("Client") {
                    Button {
                        showingClientPicker = true
                    } label: {
                        HStack {
                            if let client = selectedClient {
                                Circle()
                                    .fill(avatarColor(for: client))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(initials(for: client))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.name)
                                        .foregroundColor(.primary)
                                    if let tags = client.tags, !tags.isEmpty {
                                        Text(tags.prefix(2).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
                    .buttonStyle(.plain)
                }

                // Session Type
                Section("Session Details") {
                    Picker("Session Type", selection: $sessionType) {
                        ForEach(SessionType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }

                    if isEditing {
                        Picker("Status", selection: $status) {
                            ForEach(AppointmentStatus.allCases, id: \.self) { stat in
                                Text(statusDisplayName(stat)).tag(stat)
                            }
                        }
                    }
                }

                // Date & Time
                Section("Date & Time") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(duration) min")
                            .foregroundColor(.secondary)
                    }
                }

                // Notes
                Section("Session Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle(isEditing ? "Edit Session" : "New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedClient == nil || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClient: $selectedClient)
            }
            .task {
                // Pre-populate client if editing and client wasn't embedded
                if let existing = existingAppointment,
                   selectedClient == nil,
                   let clientId = existing.clientId {
                    selectedClient = clientViewModel.clients.first { $0.id == clientId }
                }
            }
        }
    }

    private func statusDisplayName(_ status: AppointmentStatus) -> String {
        switch status {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
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

    private func save() {
        guard let client = selectedClient else { return }

        isSaving = true

        // Combine date and time
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        startComponents.year = dateComponents.year
        startComponents.month = dateComponents.month
        startComponents.day = dateComponents.day

        let scheduledAt = calendar.date(from: startComponents) ?? startTime

        let input = AppointmentInput(
            clientId: client.id,
            scheduledAt: scheduledAt,
            duration: duration,
            sessionType: sessionType,
            status: isEditing ? status : nil,
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            var success: Bool
            if let existing = existingAppointment {
                success = await viewModel.updateAppointment(id: existing.id, input: input)
            } else {
                success = await viewModel.createAppointment(input)
            }

            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AppointmentFormView(date: Date())
        .environmentObject(AppointmentViewModel())
        .environmentObject(ClientViewModel())
}
