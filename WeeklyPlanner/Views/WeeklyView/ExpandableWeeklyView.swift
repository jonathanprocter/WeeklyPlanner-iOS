import SwiftUI

struct ExpandableWeeklyView: View {
    @EnvironmentObject var viewModel: AppointmentViewModel
    @State private var expandedDay: String? = nil
    @State private var showingAddAppointment = false
    @State private var hasAutoExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header section
                    headerSection

                    // Day list
                    dayListSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Weekly Planner")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAppointment = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddAppointment) {
                AppointmentFormView(date: viewModel.selectedDate)
            }
            .refreshable {
                await viewModel.loadAppointments()
            }
            .onChange(of: viewModel.appointments.count) { _ in
                // Auto-expand today when appointments first load
                if !hasAutoExpanded && !viewModel.appointments.isEmpty {
                    hasAutoExpanded = true
                    let today = Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    expandedDay = formatter.string(from: today)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Date navigation
            HStack {
                Button {
                    viewModel.goToPreviousWeek()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    viewModel.goToNextWeek()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            // Week summary
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.appointments.count)")
                    .font(.system(size: 42, weight: .bold))

                VStack(alignment: .leading) {
                    Text("appointments")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", viewModel.totalHoursThisWeek))h total")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Spacer()

                Button("Today") {
                    viewModel.goToToday()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: viewModel.currentWeekStart)
        let end = formatter.string(from: viewModel.weekDates.last ?? viewModel.currentWeekStart)
        formatter.dateFormat = ", yyyy"
        let year = formatter.string(from: viewModel.currentWeekStart)
        return "\(start) - \(end)\(year)"
    }

    // MARK: - Day List Section

    private var dayListSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.weekDates, id: \.self) { date in
                DayRowView(
                    date: date,
                    appointments: viewModel.appointmentsForDate(date),
                    isExpanded: expandedDay == dateKey(date),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if expandedDay == dateKey(date) {
                                expandedDay = nil
                            } else {
                                expandedDay = dateKey(date)
                            }
                        }
                    }
                )

                Divider()
                    .padding(.leading, 16)
            }
        }
        .background(Color(.systemBackground))
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Day Row View

struct DayRowView: View {
    let date: Date
    let appointments: [Appointment]
    let isExpanded: Bool
    let onToggle: () -> Void

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var totalHours: Double {
        appointments.reduce(0.0) { $0 + Double($1.duration) / 60.0 }
    }

    private var busyLevel: Color {
        switch appointments.count {
        case 0: return .gray.opacity(0.3)
        case 1: return .blue.opacity(0.4)
        case 2...3: return .blue.opacity(0.6)
        default: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row - tappable
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Indicator dot
                    Circle()
                        .fill(busyLevel)
                        .frame(width: 8, height: 8)

                    // Day name
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(dayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(isToday ? .blue : isWeekend ? .secondary : .primary)

                            if isToday {
                                Text("Today")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    Spacer()

                    // Appointment summary
                    if appointments.isEmpty {
                        Text(isWeekend ? "Off" : "Open")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(appointments.count) appts")
                                .fontWeight(.semibold)
                            Text(String(format: "%.1fh", totalHours))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Chevron (not for weekends)
                    if !isWeekend {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(isToday && !isExpanded ? Color.blue.opacity(0.05) : Color.clear)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded && !isWeekend {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color(.secondarySystemBackground) : Color.clear)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Appointments section
            if !appointments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("APPOINTMENTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(appointments) { appointment in
                        AppointmentRowCard(appointment: appointment)
                    }
                }
            }

            // Free slots section
            let freeSlots = calculateFreeSlots()
            if !freeSlots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AVAILABLE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    FlowLayout(spacing: 8) {
                        ForEach(freeSlots, id: \.self) { slot in
                            FreeSlotBadge(text: slot)
                        }
                    }
                }
            }

            // Empty state
            if appointments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)

                    Text("Fully Available")
                        .font(.headline)

                    Text("No appointments scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(16)
    }

    private func calculateFreeSlots() -> [String] {
        // Simple free slot calculation
        if appointments.isEmpty {
            return ["All day available"]
        }

        var slots: [String] = []
        let sortedAppts = appointments.sorted { $0.startTime < $1.startTime }

        // Check morning slot (before first appointment)
        if let first = sortedAppts.first {
            let firstHour = calendar.component(.hour, from: first.startTime)
            if firstHour > 9 {
                slots.append("9:00 AM - \(first.startTimeFormatted)")
            }
        }

        // Check gaps between appointments
        for i in 0..<(sortedAppts.count - 1) {
            let current = sortedAppts[i]
            let next = sortedAppts[i + 1]
            let gap = next.startTime.timeIntervalSince(current.endTime)
            if gap >= 1800 { // 30 minutes or more
                slots.append("\(current.endTimeFormatted) - \(next.startTimeFormatted)")
            }
        }

        // Check afternoon slot (after last appointment)
        if let last = sortedAppts.last {
            let lastEndHour = calendar.component(.hour, from: last.endTime)
            if lastEndHour < 17 {
                slots.append("\(last.endTimeFormatted) - 5:00 PM")
            }
        }

        return slots
    }
}

// MARK: - Appointment Row Card

struct AppointmentRowCard: View {
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
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 4, height: 44)

            // Client/Title info
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.clientName ?? appointment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(appointment.category?.rawValue.capitalized ?? "Appointment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time info
            VStack(alignment: .trailing, spacing: 2) {
                Text(appointment.startTimeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(appointment.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Free Slot Badge

struct FreeSlotBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .foregroundStyle(.green)
        .cornerRadius(16)
    }
}

// FlowLayout is defined in SessionPrepCardView.swift

#Preview {
    ExpandableWeeklyView()
        .environmentObject(AppointmentViewModel())
}
