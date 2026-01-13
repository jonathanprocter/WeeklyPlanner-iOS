import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: AppointmentViewModel
    @EnvironmentObject var clientViewModel: ClientViewModel
    let appointment: Appointment

    @StateObject private var prepViewModel = SessionPrepViewModel()
    @StateObject private var noteViewModel = SessionNoteViewModel()

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingNoteForm = false
    @State private var showingVoiceNote = false
    @StateObject private var voiceViewModel = VoiceDictationViewModel()

    private var sessionTypeColor: Color {
        switch appointment.sessionType {
        case .individual: return .blue
        case .couples: return .purple
        case .family: return .green
        case .group: return .orange
        case .none: return .gray
        }
    }

    private var client: Client? {
        appointment.client ?? clientViewModel.clientForAppointment(appointment)
    }

    private var clientName: String {
        client?.name ?? "Client"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard

                    // Time Card
                    timeCard

                    // Client Details Card (if client available)
                    if client != nil || appointment.notes != nil {
                        detailsCard
                    }

                    // Session Prep Section (for scheduled appointments with a client)
                    if appointment.status == .scheduled,
                       appointment.clientId != nil {
                        sessionPrepSection
                    }

                    // Session Note Section (for completed appointments)
                    if appointment.status == .completed {
                        sessionNoteSection
                    }

                    // Actions
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Quick voice note button
                        Button {
                            voiceViewModel.setContext(client: client, session: appointment)
                            showingVoiceNote = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.purple)
                        }
                        .accessibilityLabel("Add voice note")

                        Menu {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                AppointmentFormView(date: appointment.scheduledAt, existingAppointment: appointment)
            }
            .sheet(isPresented: $showingNoteForm) {
                SessionNoteFormView(
                    appointment: appointment,
                    client: client,
                    existingNote: noteViewModel.currentNote
                )
            }
            .sheet(isPresented: $showingVoiceNote) {
                QuickDictationOverlay(
                    viewModel: voiceViewModel,
                    client: client,
                    session: appointment,
                    onSaved: { reminder in
                        // Voice reminder saved for this client/session
                        print("Voice note saved for \(clientName): \(reminder.transcription)")
                    },
                    onDismiss: {
                        showingVoiceNote = false
                    }
                )
            }
            .onAppear {
                loadData()
            }
            .alert("Delete Session", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.deleteAppointment(id: appointment.id) {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            // Session Type Badge
            HStack {
                Text(appointment.sessionType?.rawValue.capitalized ?? "Session")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(sessionTypeColor.opacity(0.2))
                    .foregroundStyle(sessionTypeColor)
                    .cornerRadius(8)

                Spacer()

                if let status = appointment.status {
                    StatusBadge(status: status)
                }
            }

            // Title (Client Name - Session Type)
            Text(appointment.title)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Client info if embedded
            if let client = client {
                HStack(spacing: 8) {
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Time Card

    private var timeCard: some View {
        VStack(spacing: 16) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedDate)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()
            }

            Divider()

            // Time
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading) {
                    Text("Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(appointment.startTimeFormatted) - \(appointment.endTimeFormatted)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text(appointment.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: appointment.scheduledAt)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 16) {
            if let client = client {
                if let tags = client.tags, !tags.isEmpty {
                    DetailRow(
                        icon: "tag",
                        title: "Client Tags",
                        value: tags.joined(separator: ", "),
                        iconColor: .blue
                    )
                    Divider()
                }

                if let considerations = client.clinicalConsiderations, !considerations.isEmpty {
                    DetailRow(
                        icon: "exclamationmark.triangle",
                        title: "Clinical Considerations",
                        value: considerations.joined(separator: ", "),
                        iconColor: .orange
                    )
                    Divider()
                }
            }

            if let notes = appointment.notes, !notes.isEmpty {
                DetailRow(icon: "text.alignleft", title: "Session Notes", value: notes, iconColor: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if appointment.status != .completed {
                Button {
                    markAsCompleted()
                } label: {
                    Label("Mark as Completed", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Edit Session", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Session Prep Section

    private var sessionPrepSection: some View {
        Group {
            if prepViewModel.isGenerating {
                SessionPrepLoadingView()
            } else if let prep = prepViewModel.prep {
                SessionPrepCardView(
                    prep: prep,
                    clientName: clientName,
                    onRefresh: {
                        Task {
                            if let clientId = appointment.clientId {
                                await prepViewModel.refreshPrep(
                                    sessionId: appointment.id,
                                    clientId: clientId
                                )
                            }
                        }
                    }
                )
            } else if let error = prepViewModel.error {
                SessionPrepErrorView(error: error) {
                    Task {
                        if let clientId = appointment.clientId {
                            await prepViewModel.generatePrep(
                                sessionId: appointment.id,
                                clientId: clientId
                            )
                        }
                    }
                }
            } else {
                SessionPrepEmptyView(clientName: clientName) {
                    Task {
                        if let clientId = appointment.clientId {
                            await prepViewModel.generatePrep(
                                sessionId: appointment.id,
                                clientId: clientId
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Session Note Section

    private var sessionNoteSection: some View {
        Group {
            if noteViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            } else if let note = noteViewModel.currentNote {
                SessionNoteSummaryCard(note: note) {
                    showingNoteForm = true
                }
            } else {
                SessionNoteEmptyView {
                    showingNoteForm = true
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load session prep for scheduled appointments
        if appointment.status == .scheduled {
            Task {
                await prepViewModel.loadPrep(for: appointment.id)
            }
        }

        // Load session notes for the client
        if appointment.status == .completed, let clientId = appointment.clientId {
            Task {
                await noteViewModel.loadNotes(for: clientId, limit: 5)
            }
        }
    }

    private func markAsCompleted() {
        guard let clientId = appointment.clientId else { return }

        let input = AppointmentInput(
            clientId: clientId,
            scheduledAt: appointment.scheduledAt,
            duration: appointment.duration,
            sessionType: appointment.sessionType ?? .individual,
            status: .completed,
            notes: appointment.notes
        )

        Task {
            if await viewModel.updateAppointment(id: appointment.id, input: input) {
                dismiss()
            }
        }
    }

    // MARK: - Helper Functions

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

// MARK: - Supporting Views

struct StatusBadge: View {
    let status: AppointmentStatus

    private var color: Color {
        switch status {
        case .scheduled: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .noShow: return .orange
        }
    }

    var body: some View {
        Text(displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(8)
    }

    private var displayName: String {
        switch status {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
    }
}

#Preview {
    let sampleClient = Client(
        id: "client-123",
        therapistId: "therapist-1",
        name: "John Doe",
        email: "john@example.com",
        tags: ["Anxiety", "Depression"],
        clinicalConsiderations: nil,
        status: .active,
        createdAt: Date()
    )

    let sampleAppointment = Appointment(
        id: "session-123",
        clientId: "client-123",
        therapistId: "therapist-1",
        scheduledAt: Date(),
        duration: 50,
        sessionType: .individual,
        status: .scheduled,
        googleEventId: nil,
        notes: "Initial consultation",
        hasProgressNotePlaceholder: nil,
        progressNoteStatus: nil,
        isSimplePracticeEvent: nil,
        client: sampleClient,
        createdAt: Date(),
        updatedAt: nil
    )

    return AppointmentDetailView(appointment: sampleAppointment)
        .environmentObject(AppointmentViewModel())
        .environmentObject(ClientViewModel())
}
