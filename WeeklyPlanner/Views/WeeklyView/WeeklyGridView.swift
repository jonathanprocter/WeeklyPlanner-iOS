import SwiftUI

struct WeeklyGridView: View {
    @EnvironmentObject var viewModel: AppointmentViewModel
    @State private var selectedAppointment: Appointment?
    @State private var showingAddAppointment = false

    private let hours = Array(6...22) // 6 AM to 10 PM
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week Header
                weekHeader

                // Statistics Bar
                statisticsBar

                // Calendar Grid
                ScrollView([.horizontal, .vertical]) {
                    calendarGrid
                }
            }
            .navigationTitle("Weekly Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        viewModel.goToToday()
                    }
                }
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
            .refreshable {
                await viewModel.loadAppointments()
            }
        }
    }

    // MARK: - Week Header

    private var weekHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousWeek()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }

            Spacer()

            Text(weekRangeText)
                .font(.headline)

            Spacer()

            Button {
                viewModel.goToNextWeek()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
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

    // MARK: - Statistics Bar

    private var statisticsBar: some View {
        HStack(spacing: 20) {
            StatBadge(
                title: "Total Hours",
                value: String(format: "%.1fh", viewModel.totalHoursThisWeek)
            )

            StatBadge(
                title: "Appointments",
                value: "\(viewModel.appointments.count)"
            )

            if let busiest = viewModel.busiestDay {
                StatBadge(
                    title: "Busiest",
                    value: busiest
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Day Headers
            HStack(spacing: 0) {
                // Time column header
                Text("")
                    .frame(width: 60)

                ForEach(viewModel.weekDates, id: \.self) { date in
                    DayHeaderView(date: date, isToday: calendar.isDateInToday(date))
                        .frame(width: 120)
                }
            }
            .padding(.bottom, 4)

            // Time slots
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Time label
                    Text(formatHour(hour))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                        .padding(.trailing, 8)

                    // Day columns
                    ForEach(viewModel.weekDates, id: \.self) { date in
                        TimeSlotCell(
                            date: date,
                            hour: hour,
                            appointments: viewModel.appointmentsForHour(hour, on: date),
                            onTap: { appointment in
                                selectedAppointment = appointment
                            }
                        )
                        .frame(width: 120, height: 60)
                    }
                }
            }
        }
        .padding()
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct DayHeaderView: View {
    let date: Date
    let isToday: Bool

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(dayNumber)
                .font(.title3)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.blue : Color.clear)
                .clipShape(Circle())
        }
    }
}

struct TimeSlotCell: View {
    let date: Date
    let hour: Int
    let appointments: [Appointment]
    let onTap: (Appointment) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(.systemBackground))
                .border(Color(.separator), width: 0.5)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(appointments.prefix(3)) { appointment in
                    AppointmentCardView(appointment: appointment)
                        .onTapGesture {
                            onTap(appointment)
                        }
                }

                if appointments.count > 3 {
                    Text("+\(appointments.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(2)
        }
    }
}

struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WeeklyGridView()
        .environmentObject(AppointmentViewModel())
        .environmentObject(CalendarSyncViewModel())
}
