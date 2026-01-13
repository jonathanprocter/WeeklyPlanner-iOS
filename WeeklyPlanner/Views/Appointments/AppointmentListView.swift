import SwiftUI

struct AppointmentListView: View {
    @EnvironmentObject var viewModel: AppointmentViewModel
    @State private var selectedAppointment: Appointment?
    @State private var showingAddAppointment = false
    @State private var searchText = ""
    @State private var selectedCategory: AppointmentCategory?

    private var filteredAppointments: [Appointment] {
        var result = viewModel.appointments

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.clientName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        return result.sorted { $0.startTime < $1.startTime }
    }

    private var groupedAppointments: [(String, [Appointment])] {
        let grouped = Dictionary(grouping: filteredAppointments) { $0.date }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilter

                // List
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredAppointments.isEmpty {
                    emptyStateView
                } else {
                    appointmentList
                }
            }
            .navigationTitle("Appointments")
            .searchable(text: $searchText, prompt: "Search appointments")
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
                AppointmentFormView(date: Date())
            }
            .refreshable {
                await viewModel.loadAppointments()
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    color: .primary
                ) {
                    selectedCategory = nil
                }

                ForEach(AppointmentCategory.allCases, id: \.self) { category in
                    FilterChip(
                        title: category.rawValue.capitalized,
                        isSelected: selectedCategory == category,
                        color: colorForCategory(category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    private func colorForCategory(_ category: AppointmentCategory) -> Color {
        switch category {
        case .work: return .blue
        case .personal: return .green
        case .meeting: return .purple
        case .other: return .gray
        }
    }

    // MARK: - Appointment List

    private var appointmentList: some View {
        List {
            ForEach(groupedAppointments, id: \.0) { date, appointments in
                Section(header: Text(formatDateHeader(date))) {
                    ForEach(appointments) { appointment in
                        AppointmentRow(appointment: appointment)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAppointment = appointment
                            }
                    }
                    .onDelete { indexSet in
                        deleteAppointments(at: indexSet, in: appointments)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func formatDateHeader(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func deleteAppointments(at indexSet: IndexSet, in appointments: [Appointment]) {
        for index in indexSet {
            let appointment = appointments[index]
            Task {
                await viewModel.deleteAppointment(id: appointment.id)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Appointments")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your first appointment to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddAppointment = true
            } label: {
                Label("Add Appointment", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.systemBackground))
                .foregroundStyle(isSelected ? color : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color(.separator), lineWidth: 1)
                )
        }
    }
}

struct AppointmentRow: View {
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
            RoundedRectangle(cornerRadius: 4)
                .fill(categoryColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label(appointment.startTimeFormatted, systemImage: "clock")
                    Text("-")
                    Text(appointment.endTimeFormatted)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = appointment.notes, !notes.isEmpty {
                    Label(notes, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if appointment.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AppointmentListView()
        .environmentObject(AppointmentViewModel())
}
