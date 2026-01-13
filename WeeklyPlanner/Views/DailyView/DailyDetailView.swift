import SwiftUI

struct DailyDetailView: View {
    @EnvironmentObject var viewModel: AppointmentViewModel
    @State private var selectedAppointment: Appointment?
    @State private var showingAddAppointment = false
    @State private var dailyNote: DailyNote?
    @State private var noteContent = ""
    @State private var goals = ""
    @State private var reflections = ""

    private let hours = Array(6...22)
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date Picker
                    dateSelector

                    // Daily Stats
                    dailyStatsCard

                    // Timeline
                    timelineSection

                    // Daily Notes
                    dailyNotesSection
                }
                .padding()
            }
            .navigationTitle(formattedSelectedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAppointment = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedAppointment) { appointment in
                AppointmentDetailView(appointment: appointment)
            }
            .sheet(isPresented: $showingAddAppointment) {
                AppointmentFormView(date: viewModel.selectedDate)
            }
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        HStack {
            Button {
                if let newDate = calendar.date(byAdding: .day, value: -1, to: viewModel.selectedDate) {
                    viewModel.selectedDate = newDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            DatePicker(
                "",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()

            Spacer()

            Button {
                if let newDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) {
                    viewModel.selectedDate = newDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: viewModel.selectedDate)
    }

    // MARK: - Daily Stats

    private var dailyStatsCard: some View {
        let appointments = viewModel.appointmentsForDate(viewModel.selectedDate)
        let totalHours = appointments.reduce(0.0) { $0 + Double($1.duration) } / 60.0

        return HStack(spacing: 20) {
            StatCard(icon: "calendar", title: "Appointments", value: "\(appointments.count)")
            StatCard(icon: "clock", title: "Total Hours", value: String(format: "%.1fh", totalHours))
            StatCard(icon: "checkmark.circle", title: "Completed", value: "\(appointments.filter { $0.status == .completed }.count)")
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.headline)

            let appointments = viewModel.appointmentsForDate(viewModel.selectedDate)

            if appointments.isEmpty {
                emptyStateView
            } else {
                ForEach(appointments) { appointment in
                    TimelineRow(appointment: appointment)
                        .onTapGesture {
                            selectedAppointment = appointment
                        }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No appointments")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add Appointment") {
                showingAddAppointment = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Daily Notes

    private var dailyNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Notes")
                .font(.headline)

            VStack(spacing: 16) {
                NoteField(title: "Notes", text: $noteContent, placeholder: "What happened today?")
                NoteField(title: "Goals", text: $goals, placeholder: "What do you want to accomplish?")
                NoteField(title: "Reflections", text: $reflections, placeholder: "How did the day go?")

                Button("Save Notes") {
                    saveNotes()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .task {
            await loadDailyNote()
        }
        .onChange(of: viewModel.selectedDate) { _ in
            Task { await loadDailyNote() }
        }
    }

    private func loadDailyNote() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: viewModel.selectedDate)

        do {
            if let note = try await APIClient.shared.getDailyNote(date: dateString) {
                dailyNote = note
                noteContent = note.content ?? ""
                goals = note.goals ?? ""
                reflections = note.reflections ?? ""
            } else {
                noteContent = ""
                goals = ""
                reflections = ""
            }
        } catch {
            print("Error loading daily note: \(error)")
        }
    }

    private func saveNotes() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: viewModel.selectedDate)

        let input = DailyNoteInput(
            date: dateString,
            content: noteContent.isEmpty ? nil : noteContent,
            goals: goals.isEmpty ? nil : goals,
            reflections: reflections.isEmpty ? nil : reflections
        )

        Task {
            do {
                _ = try await APIClient.shared.saveDailyNote(input)
            } catch {
                print("Error saving daily note: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TimelineRow: View {
    let appointment: Appointment

    private var categoryColor: Color {
        switch appointment.category {
        case .work: return .blue
        case .personal: return .green
        case .meeting: return .purple
        case .other, .none: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(appointment.startTimeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(appointment.endTimeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 4)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let notes = appointment.notes, !notes.isEmpty {
                    Label(notes, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(appointment.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status indicator
            if appointment.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct NoteField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }
}

#Preview {
    DailyDetailView()
        .environmentObject(AppointmentViewModel())
}
